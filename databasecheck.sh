#MySQL database checker and fixer https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh
#Version 0.22
#To parse logs: :D means it is repairing successfully. :| means that it did nothing. :? means that it doesn't deal with it.

#this is so that you can use the current date in anything you need it in [logfiles,backups]
thedate=`date | sed -e s/" "/_/g`;
#This is taken from mysqltunr and counts the number of fractured tables. :)
fracturedtables=`mysql -Bse "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY';"`
#Check to make sure mysql version is 5.x . Also, reset the logs [tee, not tee -a]
if [ `mysql -V | awk '{print $5}' | cut -d "." -f -1` == "5" ]; then
  echo "You have MySQL 5 or an equivalent :D" tee /tmp/dblogfile
  echo "Current number of fractured tables: $fracturedtables" tee /tmp/dblogfile
  else echo "you don't have MySQL 5! don't run this >.>" | tee /tmp/dblogfile; break
fi
#Ask because this takes forever D:
echo -e "Would you like to check space for backups? y for yes"
read checkspace
if [ $checkspace == "y" ]; then
  datadir=`grep datadir /etc/my.cnf | sed s/"datadir="//g`
  echo "Space left is:" `df -h | awk '{print $4}' | head -n2 | tail -n1` "and space MySQL takes up is:" `du -sh $datadir` | tee -a /tmp/dblogfile
fi
echo -e "Would you like to make backups? y for yes"
read backups
if [ $backups == "y" ]; then
  mkdir -p /home/sqldumps/$thedate; 
  cd /home/sqldumps/$thedate; 
  for i in $(mysql -BNe 'show databases'| grep -v _schema); do `mysqldump $i > ./$i.sql` ; echo "we have backed up "$i | tee -a /tmp/dblogfile ;done
fi
echo "Would you actually like to run MyISAM mysqlchecks (no downtime)? Type y for yes"
read myisam
echo "Would you actually like to run InnoDB alter table commands? Type y for yes"
read innodb
#echo the choices into the logfile when the logfile works
echo "Backups=" $backups, "MyISAM=" $myisam, "InnoDB=" $innodb | tee -a /tmp/dblogfile
#for loop, grab all the databases
for database in $(mysql -e "SHOW DATABASES;"|tail -n+2); do
#for each database, grab all the tables
  for table in $(mysql -e "use $database; show tables;" | tail -n+2); do
#find the type of engine the table is running in
     tabletype=`mysql -e "SELECT ENGINE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='$table' AND TABLE_SCHEMA='$database';" | tail -n+2`
#check to see which table and fix it with a preferred method for each, or spout information
    if [ $tabletype == "InnoDB" ]; then
         if [ $innodb == y ]; then
              echo "$table in $database is InnoDB, rebuilding with alter table command :D" | tee -a /tmp/dblogfile
              mysql -e "use $database; ALTER TABLE $table ENGINE = InnoDB" | tee -a /tmp/dblogfile
              else echo "$table in $database is InnoDB, doing nothing - disabled :|" | tee -a /tmp/dblogfile
         fi
    elif [ $tabletype == "MyISAM" ]; then
         if [ $myisam == y ]; then
              echo "$table in $database is MyISAM, repairing with mysqlcheck :D" | tee -a /tmp/dblogfile
              mysqlcheck --auto-repair --optimize $database $table | tee -a /tmp/dblogfile
              else echo "$table in $database is MyIsam, doing nothing - disabled :|" | tee -a /tmp/dblogfile
         fi 
    elif [ $tabletype == "MERGE" ]; then
         echo "$table in $database is MERGE, checking table :D Maybe you can fix with a UNION command, but I don't do that." | tee -a /tmp/dblogfile
         mysql -e "use $database; CHECK TABLE $table" | tee -a /tmp/dblogfile
    else echo "$table in $database has tabletype $tabletype and is not anything I actively fix. :? Not altering." | tee -a /tmp/dblogfile
    fi
  done
done
#Tell them about the logs now that it's run!
echo "Current number of fractured tables: $fracturedtables" tee /tmp/dblogfile
echo "Finished! If you're wondering exactly what happened, logs for this are created in /tmp/dblogfile. If you want, you can do a MyISAM check if there are still too many broken tables. Just type 'y'.
WARNING: THIS WILL SHUT DOWN YOUR MYSQL SERVER FOR THE DURATION OF THE CHECK."
read myisamcheck;
if [ $myisamcheck == y ];
  service mysql stop && chmod -x /usr/bin/mysql && chmod -x /usr/sbin/mysqld
  myisamchk --safe-recover --key_buffer_size=1G --read_buffer_size=300M --write_buffer_size=300M --sort_buffer_size=2G /var/lib/mysql/*/*.MYI | tee -a /tmp/dblogfile
  chmod +x /usr/bin/mysql && chmod +x /usr/sbin/mysqld && service mysql start
  echo "Current number of fractured tables: $fracturedtables" tee /tmp/dblogfile
  echo "Your files are as fixed as possible! Have a great day. :D"
else echo "Good choice, I think. :) Hopefully this helped."
fi
