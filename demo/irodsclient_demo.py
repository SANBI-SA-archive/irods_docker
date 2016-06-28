#!/usr/bin/env python

# this uses python-irodsclient
# https://github.com/irods/python-irodsclient

from __future__ import print_function
import os.path
import hashlib
from irods.session import iRODSSession
from irods.exception import DataObjectDoesNotExist

sess = iRODSSession(host='localhost', port=32770, user='rods', password='rods', zone='b3devZone')
path = '/b3devZone/home/rods/hello.txt'
try:
    sess.data_objects.get(path)
except DataObjectDoesNotExist:
    obj = sess.data_objects.create(path)
    with obj.open('w') as output:
	print("Hello World\n", file=output)
    obj.metadata.add('mood', 'happy')

filename = 'manifesto.txt'
directory = '/b3devZone/home/rods'
path = os.path.join(directory, filename)
try:
    sess.data_objects.get(path)
    sess.data_objects.unlink(path)
except DataObjectDoesNotExist:
    pass
obj = sess.data_objects.create(path)
with open(filename) as input:
    with obj.open('w') as output:
        for line in input:
            output.write(line)
obj.metadata.add('mood', 'determined')

local_hash = hashlib.sha256()
with open(filename) as input:
    local_hash.update(input.read())
remote_hash = hashlib.sha256()
with obj.open('r') as input:
    remote_hash.update(input.read())

if local_hash.hexdigest() == remote_hash.hexdigest():
    print("Data verification passed")
else:
    print("Got a verification problem, local {} vs remote {}".format(local_hash.hexdigest(), remote_hash.hexdigest()))

