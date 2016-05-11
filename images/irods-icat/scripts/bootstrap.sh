#!/bin/bash
FIRSTRUN_DONE=/conf/irods-icat-firstrundone.txt

echo ">>>"`basename $0`
echo ">>> testing for first run" 	

IRODS_HOME_DIR="/home/irods"

# config-existing-irods.sh
# Author: Michael Stealey <michael.j.stealey@gmail.com>

SERVICE_ACCOUNT_CONFIG_FILE="/etc/irods/service_account.config"
IRODS_INSTALL_DIR="/var/lib/irods"

IRODS_CONFIG_SH_FILE='irods-config.sh'
IRODS_CONFIG_FILE="irods-config.yaml"
IRODS_SETUP_FILE='setup_responses'

. /conf/$IRODS_CONFIG_SH_FILE

# get service account name
MYACCTNAME=`echo "${SERVICE_ACCT_USERNAME}" | sed -e "s/\///g"`

# get group name
MYGROUPNAME=`echo "${SERVICE_ACCT_GROUP}" | sed -e "s/\///g"`

if [[ ! -e $FIRSTRUN_DONE ]] ; then

  echo "running first setup"

  if [[ -e /conf/$IRODS_CONFIG_FILE ]] ; then
      echo "*** Importing existing configuration file: /conf/${IRODS_CONFIG_FILE} ***"
      cp /conf/${IRODS_CONFIG_FILE} /files;
  else
      echo "*** Generating configuration file: /files/${IRODS_CONFIG_FILE} ***"
      /scripts/generate-config-file.sh /files/${IRODS_CONFIG_FILE}
      cp /files/${IRODS_CONFIG_FILE} /conf;
  fi

  # echo "running irods package postinstall"
  # /var/lib/irods/packaging/postinstall.sh /var/lib/irods icat

  # generate configuration responses
  echo "generating responses file"
  /scripts/generate-irods-response.sh /files/$IRODS_SETUP_FILE

  # wait for postgres server to spin up
  /usr/local/bin/waitforit.sh irods-db:5432

  # set up the iCAT database
  echo "setting up database"
  /scripts/setup-irods-db-admin.sh /files/$IRODS_SETUP_FILE

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

  # echo $MYACCTNAME $MYGROUPNAME $IRODS_ZONE $IRODS_PORT $RANGE_BEGIN $RANGE_END $VAULT_DIRECTORY $NEGOTIATION_KEY \
  #      $CONTROL_PLANE_PORT $CONTROL_PLANE_KEY $SCHEMA_VALIDATION_BASE_URI $ADMINISTRATOR_USERNAME $ADMINISTRATOR_PASSWORD yes \
  #     irods-db 5432 ICAT $IRODS_DB_ADMIN_USER $IRODS_DB_ADMIN_PASS yes 
  cat /files/$IRODS_SETUP_FILE | $IRODS_INSTALL_DIR/packaging/setup_irods.sh

  chown -R $MYACCTNAME:$MYGROUPNAME $IRODS_INSTALL_DIR

  # change irods user's irods_environment.json file to point to localhost, since it was configured with a transient Docker container
  # sed -i 's/"irods_host".*/"irods_host": "localhost",/g' $IRODS_HOME_DIR/.irods/irods_environment.json
  
  touch $FIRSTRUN_DONE
fi

# set permissions on iRODS authentication mechanisms
chmod 4755 ${IRODS_INSTALL_DIR}/iRODS/server/bin/PamAuthCheck
chmod 4755 /usr/bin/genOSAuth

chown ${MYACCTNAME}:${MYGROUPNAME} /var/lib/irods/iRODS/server/log

# start iRODS server as user irods
# su ${MYACCTNAME} <<EOF
# /var/lib/irods/iRODS/irodsctl restart
# while read line; do iadmin modresc ${line} host `hostname`; done < <(ilsresc)
# EOF

# OPTIONAL: Install irods-dev
#rpm -i $(ls -l | tr -s ' ' | grep irods-dev | cut -d ' ' -f 9)
# Install irods-runtime
#rpm -i $(ls -l | tr -s ' ' | grep irods-runtime | cut -d ' ' -f 9)
# Install irods-microservice-plugins
#rpm -i $(ls -l | tr -s ' ' | grep irods-microservice-plugins | cut -d ' ' -f 9)



# Keep container in a running state
/usr/bin/tail -f /dev/null




##########################
