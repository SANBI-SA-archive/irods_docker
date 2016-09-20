#!/bin/bash
FIRSTRUN_DONE=/conf/irods-icat-firstrundone.txt

echo ">>>"`basename $0`

IRODS_HOME_DIR="/home/irods"

IRODS_INSTALL_DIR="/var/lib/irods"

IRODS_CONFIG_SH_FILE='irods-config.sh'
IRODS_CONFIG_FILE="irods-config.yaml"
IRODS_SETUP_FILE='setup_responses'

sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" /conf/$IRODS_CONFIG_FILE > /conf/$IRODS_CONFIG_SH_FILE

. /conf/$IRODS_CONFIG_SH_FILE

# get service account name
MYACCTNAME=`echo "${SERVICE_ACCT_USERNAME}" | sed -e "s/\///g"`

# get group name
MYGROUPNAME=`echo "${SERVICE_ACCT_GROUP}" | sed -e "s/\///g"`

# wait for postgres server to spin up
echo "Wait for DB server to be ready"
OLD_PGPASSWORD=""
if [ -n "$PGPASSWORD" ] ; then 
  OLD_PGPASSWORD=$PGPASSWORD
fi
export PGPASSWORD=$PGSETUP_POSTGRES_PASSWORD
/usr/local/bin/waitforit.sh -d ICAT irods-db:5432
if [ -N "$OLD_PGPASSWORD" ] ; then
  PGPASSWORD=$OLD_PGPASSWORD
else
  unset PGPASSWORD
fi

if [[ ! -e $FIRSTRUN_DONE ]] ; then

  echo "running first setup"

  # generate configuration responses
  echo "generating responses file"
  /scripts/generate-irods-response.sh /conf/$IRODS_CONFIG_FILE /files/$IRODS_SETUP_FILE

  echo "setting up ICAT database"

  SECRETS_DIRECTORY='/root/.secret'
  SECRETS_FILE="${SECRETS_DIRECTORY}/secrets.yaml"

  # PGSETUP_POSTGRES_PASSWORD is set externally, in docker-compose.yml
  PGPASSWORD=${PGSETUP_POSTGRES_PASSWORD}
  export PGPASSWORD

  # Rename existing database to ICAT - not needed anymore
  #psql -U postgres -h ${HOSTNAME_OR_IP} -c "ALTER DATABASE \"${PGSETUP_DATABASE_NAME}\" RENAME TO \"ICAT\""
  # Create irods database user and grant all privileges to that user
  psql -U postgres -h ${HOSTNAME_OR_IP} -c "CREATE USER ${DATABASE_USER} WITH PASSWORD '${DATABASE_PASSWORD}'"
  psql -U postgres -h ${HOSTNAME_OR_IP} -c "GRANT ALL PRIVILEGES ON DATABASE \"ICAT\" TO ${DATABASE_USER}"
  unset PGPASSWORD

  # Update secrets file with new information - not needed anymore
  #sed -i "s/${PGSETUP_DATABASE_NAME}/ICAT/g" $SECRETS_FILE

  cat << EOF > $SECRETS_FILE
  PGSETUP_DATABASE_NAME: ICAT
  PGSETUP_POSTGRES_PASSWORD: $PGSETUP_POSTGRES_PASSWORD
  IRODS_DB_ADMIN_USER: $DATABASE_USER
  IRODS_DB_ADMIN_PASS: $DATABASE_PASSWORD
EOF

  # Refresh environment variables derived from updated secrets
  sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" $SECRETS_FILE > $SECRETS_DIRECTORY/secrets.sh

  mkdir /home/irods/.irods
  IRODS_USER_ENVIRONMENT_FILE=/home/irods/.irods/irods_environment.json
  echo "Creating $IRODS_USER_ENVIRONMENT_FILE"
  echo -e '{\n   "irods_user_name": "ADMINISTRATOR_USERNAME",\n  "irods_host": "localhost",\n  "irods_port": 1247,\n  "irods_zone_name": "IRODS_ZONE"\n}' > $IRODS_USER_ENVIRONMENT_FILE

  sed -i "s/ADMINISTRATOR_USERNAME/$ADMINISTRATOR_USERNAME/" $IRODS_USER_ENVIRONMENT_FILE
  sed -i "s/IRODS_ZONE/$IRODS_ZONE/" $IRODS_USER_ENVIRONMENT_FILE
  cat $IRODS_USER_ENVIRONMENT_FILE

  # copy in place files and templates
  ( cd $IRODS_INSTALL_DIR/packaging
    cp server_config.json.template server_config.json
    cp database_config.json.template database_config.json
    cp hosts_config.json.template /etc/irods/hosts_config.json
    cp host_access_control_config.json.template /etc/irods/host_access_control_config.json
#    mkdir /etc/irods/reConfigs
    cp core.re.template $IRODS_INSTALL_DIR/iRODS/server/config/reConfigs/core.re
    cp core.fnm.template $IRODS_INSTALL_DIR/iRODS/server/config/reConfigs/core.fnm
    cp core.dvm.template $IRODS_INSTALL_DIR/iRODS/server/config/reConfigs/core.dvm
  )

  . /root/.secret/secrets.sh

  echo "*:*:*:${DATABASE_USER}:${DATABASE_PASSWORD}" > /home/irods/.pgpass
  chown $MYACCTNAME /home/irods/.pgpass
  chmod 600 /home/irods/.pgpass

  echo "*:*:*:${DATABASE_USER}:${DATABASE_PASSWORD}" > /root/.pgpass
  chmod 600 /root/.pgpass

  echo -e "[postgres]\nDriver=/usr/lib64/psqlodbc.so\nDebug=0\nCommLog=0\nServername=${HOSTNAME_OR_IP}\nDatabase=ICAT\nReadOnly=no\nKsqo=0\nPort=5432" >/home/irods/.odbc.ini
  chown $MYACCTNAME /home/irods/.odbc.ini
  
  
#  chown -R $MYACCTNAME /home/irods/.irods

  echo "test database connectivity"
  gosu $MYACCTNAME sh -c "echo '\dt' | psql -U irods -h irods-db ICAT" >/dev/null 2>&1
  if [[ $? -ne 0 ]] ; then
    echo "Failed to connect to database, setup will fail" >&2
    exit 1
  fi

  # alternatives here: either echo all these variables to setup_irods.sh
  # echo $MYACCTNAME $MYGROUPNAME $IRODS_ZONE $IRODS_PORT $RANGE_BEGIN $RANGE_END $VAULT_DIRECTORY $NEGOTIATION_KEY \
  #      $CONTROL_PLANE_PORT $CONTROL_PLANE_KEY $SCHEMA_VALIDATION_BASE_URI $ADMINISTRATOR_USERNAME $ADMINISTRATOR_PASSWORD yes \
  #     irods-db 5432 ICAT $IRODS_DB_ADMIN_USER $IRODS_DB_ADMIN_PASS yes 
  # or use a "responses file" and cat that to setup_irods.sh
  # either way this needs to change if setup_irods.sh changes
  cat /files/$IRODS_SETUP_FILE | $IRODS_INSTALL_DIR/packaging/setup_irods.sh

  chown -R $MYACCTNAME /home/irods
  chown -R $MYACCTNAME $IRODS_INSTALL_DIR
  chown -R $MYACCTNAME /etc/irods

  # change irods user's irods_environment.json file to point to localhost, since it was configured with a transient Docker container
  # sed -i 's/"irods_host".*/"irods_host": "localhost",/g' $IRODS_HOME_DIR/.irods/irods_environment.json
  
  gosu $MYACCTNAME perl $IRODS_INSTALL_DIR/iRODS/irodsctl stop
  touch $FIRSTRUN_DONE
fi

chown -R $MYACCTNAME /home/irods
chown -R $MYACCTNAME $IRODS_INSTALL_DIR
chown -R $MYACCTNAME /etc/irods
# start and stop server to check it is working
gosu $MYACCTNAME perl $IRODS_INSTALL_DIR/iRODS/irodsctl start
/usr/local/bin/waitforit.sh localhost:$IRODS_PORT
gosu $MYACCTNAME perl $IRODS_INSTALL_DIR/iRODS/irodsctl stop
sleep 6
echo "Starting iRODS server"
exec gosu $MYACCTNAME sh -c "cd $IRODS_INSTALL_DIR/iRODS/server/bin ; $IRODS_INSTALL_DIR/iRODS/server/bin/irodsServer -u"

