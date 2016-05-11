#!/bin/bash

# setup-irods-db-admin.sh
# Author: Michael J. Stealey <michael.j.stealey@gmail.com>

echo "Start of setup-irods-admin.sh"


RESPFILE=$1
IRODS_DB_ADMIN_USER=`tail -n 3 $RESPFILE | head -n 1`
IRODS_DB_ADMIN_PASS=`tail -n 2 $RESPFILE | head -n 1`
IRODS_CONFIG_FILE='/conf/irods-config.yaml'
SECRETS_DIRECTORY='/root/.secret'
SECRETS_FILE="${SECRETS_DIRECTORY}/secrets.yaml"

# read irods-config.yaml into environment
sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" $IRODS_CONFIG_FILE > /root/.secret/irods-secrets.sh
while read line; do export $line; done < <(cat /root/.secret/irods-secrets.sh)

# Get secrets from postgresql install
#sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" $SECRETS_FILE > $SECRETS_DIRECTORY/secrets.sh
#while read line; do export $line; done < <(cat $SECRETS_DIRECTORY/secrets.sh)

# Create .pgpass file for user postgres
# echo "*:*:*:*:${PGSETUP_POSTGRES_PASSWORD}" > /var/lib/pgsql/.pgpass
# chmod 0600 /var/lib/pgsql/.pgpass
# chown postgres:postgres /var/lib/pgsql/.pgpass

# Rename existing database to ICAT
#sudo -u postgres psql -h ${HOSTNAME_OR_IP} -c "ALTER DATABASE \"${PGSETUP_DATABASE_NAME}\" RENAME TO \"ICAT\""
# Create irods database user and grant all privileges to that user
PGPASSWORD=${PGSETUP_POSTGRES_PASSWORD}
export PGPASSWORD
psql -U postgres -h ${HOSTNAME_OR_IP} -c "CREATE USER ${IRODS_DB_ADMIN_USER} WITH PASSWORD '${IRODS_DB_ADMIN_PASS}'"
psql -U postgres -h ${HOSTNAME_OR_IP} -c "GRANT ALL PRIVILEGES ON DATABASE \"ICAT\" TO ${IRODS_DB_ADMIN_USER}"

# Update secrets file with new information
#sed -i "s/${PGSETUP_DATABASE_NAME}/ICAT/g" $SECRETS_FILE

cat << EOF > $SECRETS_FILE
PGSETUP_DATABASE_NAME: ICAT
PGSETUP_POSTGRES_PASSWORD: $PGSETUP_POSTGRES_PASSWORD
IRODS_DB_ADMIN_USER: $IRODS_DB_ADMIN_USER
IRODS_DB_ADMIN_PASS: $IRODS_DB_ADMIN_PASS
EOF

# Refresh environment variables derived from updated secrets
sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" $SECRETS_FILE > $SECRETS_DIRECTORY/secrets.sh
while read line; do export $line; done < <(cat $SECRETS_DIRECTORY/secrets.sh)

exit;
