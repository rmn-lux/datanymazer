#!/bin/bash

set -euo pipefail

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
    DATABASE_PORT="$(echo $DATABASE_URL | awk -F ":" '{print $4}' | awk -F "/" '{print $1}')"
    DATABASE_HOST="$(echo $DATABASE_URL | awk -F "@" '{print $2}' | awk -F ":" '{print $1}')"
    DATABASE_NAME=$(echo $DATABASE_URL | awk -F "@" '{print $2}' | awk -F "/" '{print $2}')
    
    if [[ $(pg_isready -h "${DATABASE_HOST}" -p "${DATABASE_PORT}") ]] ; then
        echo "${DATABASE_HOST}:${DATABASE_PORT} - accepting connections"
        return 0
    else
        echo "Could not connect to ${DATABASE_HOST}"
        exit 1
    fi
}

check_s3_bucket_connection() {
    if [[ $(aws --no-verify-ssl --endpoint-url "${AWS_ENDPOINT}" s3api list-buckets) ]] ; then
        echo "${AWS_ENDPOINT} - connection to S3 bucket OK"
        return 0
    else
        echo "Could not connect to S3 bucket at ${AWS_ENDPOINT}"
        exit 1
    fi
}

pg_datanymizer --version

env
ls -l /etc/datanymazer || true
cat /etc/datanymazer/dvdrental.yml || true

tailf -f /dev/null

# check connections and vars
check_empty_vars
check_psql_alive
check_s3_bucket_connection

exec pg_datanymizer "${DATABASE_URL}" \
-c "${CONFIG_PATH}" | gzip | aws --no-verify-ssl --endpoint-url "${AWS_ENDPOINT}" s3 cp - s3://"${S3_BUCKET_NAME}"/"${S3_OBFUSCATION_PATH}"/"${DATABASE_NAME}"/"$(date +%Y)"/"$(date +%m)"/$(date +%d).dump.gz \
&& echo -e "\nDump $(date +%d).dump.gz of ${DATABASE_NAME} has been uploaded to S3 ${S3_BUCKET_NAME} bucket"
