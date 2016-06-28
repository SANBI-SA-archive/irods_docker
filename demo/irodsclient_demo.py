#!/usr/bin/env python

# this uses python-irodsclient
# https://github.com/iPlantCollaborativeOpenSource/python-irodsclient

from __future__ import print_function
from irods.session import iRODSSession

sess = iRODSSession(host='localhost', port=32770, user='rods', password='rods', zone='b3devZone')
obj = sess.data_objects.create('/b3devZone/home/rods/hello.txt')
with obj.open('w') as output:
    print("Hello World\n", file=output)
obj.metadata.add('mood', 'happy')

