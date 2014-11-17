squid-mongodb-logger
====================

Logging script to insert Squid 3.x access.log to a MongoDB collection

Configuration file
==================
The configuration file contains the database connection parameters, written as key: value pairs, one per line.
Example:
host: localhost
database: hoplogs
collection: squid
user: squid
pass: 123456
(It's a YAML file.)

host
Host where the DB server is running. If unspecified, 'localhost' is assumed.

database
Name of the database to connect to. If unspecified, 'squid_log' is assumed.
table
Name of the database table where log lines are stored. If unspecified, 'access_log' is assumed.
username
Username to use when connecting to the database. If unspecified, 'squid' is assumed.
password
Password to use when connecting to the database. If unspecified, no password is used.

To leave all fields to their default values, just create the configuration file and don't write anything in it.

To only specify the database password, put this single line in the configuration file:
pass: <password>

Security note

This file should be owned by root and its permission bits should be set to 600.

BUGS & TODO
===========
Squid version
=============
CHANGELOG
=========
AUTHOR
======
Nishant Sharma, codemarauder@gmail.com
Modified the original script by Marcello Romani which used to insert logs
into MySQL DB. This version inserts the logs to MongoDB.

ORIGINAL AUTHOR
===============
Marcello Romani, marcello.romani@libero.it

COPYRIGHT AND LICENSE
=====================

Copyright (C) 2008 by Marcello Romani

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

