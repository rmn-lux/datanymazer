#!/bin/bash

set -eo pipefail

check_empty_vars() {
    vars=$(env | awk -F "=" '{print $1}' | grep -v "^_\$")

    for line in $vars
        do
            if [[ -z "${!line}" ]]; then
            echo "Variable $line should not be empty"
            exit 1
            fi
        done
}

check_psql_alive() {
    # parse incoming string like postgres://"${POSTGRESQL_USERNAME}":"${POSTGRESQL_PASSWORD}"@"${DATABASE_URL}"/"${POSTGRESQL_DATABASE} for local check psql alive" 
    export DATABASE_PORT="$(echo $DATABASE_URL | awk -F ":" '{print $4}' | awk -F "/" '{print $1}')"
    export DATABASE_HOST="$(echo $DATABASE_URL | awk -F "@" '{print $2}' | awk -F ":" '{print $1}')"
    export DATABASE_NAME=$(echo $DATABASE_URL | awk -F "@" '{print $2}' | awk -F "/" '{print $2}')
    
    export psql_check="pg_isready -h "${DATABASE_HOST}" -p "${DATABASE_PORT}""  

    ${psql_check} >/dev/null || exit_code="$?" # check exit code because using set -e in script

    if [[ "${exit_code}" -ne 0 ]] ; then
        ${psql_check}
        exit 1
    else
        ${psql_check}
    fi
}

check_s3_bucket_connection() {
    export check_s3_bucket_connection="aws --cli-connect-timeout 1 --endpoint-url "${AWS_ENDPOINT}" s3api list-buckets"

    $check_s3_bucket_connection >/dev/null 2>&1 || exit_code="$?"  # check exit code because using set -e in script

    if [[ "${exit_code}" -ne 0 ]] ; then
        echo "Connect timeout on endpoint URL: ${AWS_ENDPOINT}"
        exit 1
    else
        echo "Connection to ${AWS_ENDPOINT} is successful"
    fi
}

pg_datanymizer --version

# check connections and vars
check_empty_vars
check_psql_alive
check_s3_bucket_connection

exec pg_datanymizer "${DATABASE_URL}" \
-c "${CONFIG_PATH}" | gzip | aws --endpoint-url "${AWS_ENDPOINT}" s3 cp - s3://"${S3_BUCKET_NAME}"/"${S3_OBFUSCATION_PATH}"/"${DATABASE_NAME}"/"$(date +%Y)"/"$(date +%m)"/$(date +%d).dump.gz \
&& echo -e "\nDump $(date +%d).dump.gz of ${DATABASE_NAME} has been uploaded to S3 ${S3_BUCKET_NAME} bucket"
