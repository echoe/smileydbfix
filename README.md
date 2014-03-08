databasecheck.sh: a database tuning script meant to be used in concert with mysqltuner, or just if you want to fix any broken mysql databases.
works currently for MySQL 5 [mainly] and MariaDB [as the commands as the same]. To be blunt, it checks the version of the table, and if the table is already InnoDB, it alters it to InnoDB [which is the MySQL-man-page approved way to fix any fragmented tables]. If the table is MyISAM, it runs a mysqlcheck on it. Before the script runs it asks four questions: you can run it where it skips any of the checks.

There is an option to run a MyISAM check on the MyISAM tables. This turns MySQL off as it runs, by first turning MySQL off and making the /usr/sbin/mysqld script non-executable. As such, I've added a warning there to be sure that it isn't run accidentally.

It also currently will let you know how effective it was by outputting the current number of fragmented tables. It also outputs logs of it fixing the tables within the file /tmp/dblogfile . If you see anything else that you would like to be added to it, just drop me a line.
