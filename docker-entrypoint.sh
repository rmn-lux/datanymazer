#!/bin/bash

set -eo pipefail

check_rails_migrations() {
    local query="select now()"
    export PGPASSWORD="${POSTGRESQL_PASSWORD}" # env for psql pass

    if [[ ! -z "${RAILS_LAST_SCHEMA_MIGRATION}" ]]; then
        current_migration=$(psql -h "${POSTGRESQL_ADDRESS}" -p "${POSTGRESQL_PORT}" -d "${POSTGRESQL_DATABASE}" -U "${POSTGRESQL_USERNAME}" -t -c "$query" | tr -d [:space:])
        echo "$current_migration"

        # if [[ "$current_migration" != "${RAILS_LAST_SCHEMA_MIGRATION}" ]]; then
        #     echo "Current migration in env variable $current_migration not equal migration in database"
        #     exit 1
        # else
        #     echo "The migration specified in the environment variable is the same as the migration in the database, continue..."
        # fi
    fi
}

check_empty_vars() {
    vars=$(env | awk -F "=" '{print $1}' | egrep -v "^_\$|RAILS_LAST_SCHEMA_MIGRATION")

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
    export POSTGRESQL_PORT="$(echo $DATABASE_URL | awk -F ":" '{print $4}' | awk -F "/" '{print $1}')"
    export psql_check="pg_isready -h "${POSTGRESQL_ADDRESS}" -p "${POSTGRESQL_PORT}""  

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
check_rails_migrations

exec pg_datanymizer "${DATABASE_URL}" \
-c "${CONFIG_PATH}" | gzip | aws --endpoint-url "${AWS_ENDPOINT}" s3 cp - s3://"${S3_BUCKET_NAME}"/"${S3_OBFUSCATION_PATH}"/"${POSTGRESQL_DATABASE}"/"$(date +%Y)"/"$(date +%m)"/$(date +%d).dump.gz \
&& echo -e "\nDump $(date +%d).dump.gz of ${POSTGRESQL_DATABASE} has been uploaded to S3 ${S3_BUCKET_NAME} bucket"
