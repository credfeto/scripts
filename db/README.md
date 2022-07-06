# Database Scripts

### Linux


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

``Repo/.database`` => file containing the DatabaseName for synchronising
