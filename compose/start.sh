#!/bin/bash

if [[ ! -d /srv ]] ; then
  echo "You need a /srv directory for this to work." >&2
  exit 1
fi

#if [[ ! -O /srv ]] ; then
#  echo "The /srv directory must be owned by the user that runs this script." >&2
#  exit 1
#fi

docker-compose up

docker rm irods-icat
docker rm compose_irods-db_1
docker rm compose_appstack-data_1

