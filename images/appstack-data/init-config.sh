#!/bin/sh

CONFIG_FILE=rodsuser-config.yaml
if [ ! -f /conf/${CONFIG_FILE} ] ; then
  cp -r /config-files/*.yaml /conf
fi

tail -f /dev/null
