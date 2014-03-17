databasecheck.sh: a database tuning script meant to be used in concert with mysqltuner, or just if you want to fix any broken mysql databases.
This works currently for MySQL 5 [mainly] and MariaDB [as the commands are the same]. It works like so:
It checks the version of the table using MySQL commands, and if the table is already InnoDB, it alters it to InnoDB [which is the MySQL manpage approved way to fix any fragmented tables]. If the table is MyISAM, it runs a mysqlcheck on it. Before the script runs it asks some questions: 
-Do you want to check space? This mainly works as a reminder/space check, but for certain massive directories, you don't want to du.
-Do you want to make backups? These are written to /home/sqldumps/[the date].
-Which types of checks do you want to run? InnoDB, MySQLcheck, or MyISAM check.

This script outputs logs of it fixing the tables within the file /tmp/dblogfile and records your choices there as well. If you see anything else that you would like to be added to it, just drop me a line [or edit it yourself! :P].
