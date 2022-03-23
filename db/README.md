# Database Scripts

### Linux


* ``install-mssql`` -> installs latest MSSQL as a docker instance
* ``createdb`` -> creates a named database
* ``updatedb`` -> runs Redgate sqlcompare in docker and populates the database **
*``extractdb`` -> runs Redgate sqlcompare in docker extracts the database to files **
* ``dbappsettings`` -> creates\updates appsettings-local.json in each project with the connection string to the DB

** Assumes appropriate license for Redgate SQLCompare

These scripts use the following files:
* ``~/.database`` - file containing properties for talking to mssql

SERVER=localhost
USER=sa
PASSWORD=NotTellingYou!

``Repo/.database`` => file containing the DatabaseName for synchronising
