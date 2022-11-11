# Database Scripts

## Prerequisites

## Linux
* docker needs to be installed
* sqlcmd needs to be installed e.g. ``yay -Sy mssql-tools``

### Mac OS X
* docker needs to be installed
* sqlcmd needs to be installed see [mssql-tools](https://ports.macports.org/port/mssql-tools/)

## Scripts

* ``install-mssql`` -> installs latest MSSQL as a docker instance
* ``createmssqldb`` -> creates a named database
* ``updatedb`` -> runs Redgate sqlcompare in docker and populates the database [1]
* ``extractdb`` -> runs Redgate sqlcompare in docker extracts the database to files [1]
* ``dbappsettings`` -> creates\updates appsettings-local.json in each project with the connection string to the DB

[1] Assumes appropriate license for Redgate SQLCompare

These scripts use the following files:
* ``~/.database`` - file containing properties for talking to mssql

```
SERVER=localhost
USER=sa
PASSWORD=NotTellingYou!
```

Note: if SERVER is set as localhost then the local docker instance will be used

* ``Repo/.database`` => file containing the DatabaseName for synchronising

```
DB=MyDatabaseName
```
### Common Command line parameters

* ``--server servername`` - overrides the server name in ~/.database
* ``--database database`` - overrides the database name in repo/.database
* ``--user username`` - overrides the username name in ~/.database
* ``--password password`` - overrides the username name in ~/.database

## Commands

### ``install-mssql``

* Installs the latest MSSQL docker image as a named container ``mssql`` with networking set up to allow connections from redgate instance
* Uses ~/.database to set get the connection details for the database

Usage:
```bash
./install-mssql --data /home/mssql
```

### ``createmssqldb``
* Creates a named database reading ``Repo/.database`` for DB name and ``~/.database`` for connection details

### ``updatedb``
* Updates a named database reading ``Repo/.database`` for DB name and ``~/.database`` for connection details reading the db schema from ``Repo/db`` folder.

### ``extractdb``
* Saves a named database reading ``Repo/.database`` for DB name and ``~/.database`` for connection details saving the db schema from ``Repo/db`` folder.

Note:
* this does not update the content of static data tables

### ``dbappsettings``
* Creates\updates appsettings-local.json in each project with the connection string to the DB
