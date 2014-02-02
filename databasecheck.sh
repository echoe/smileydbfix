#MySQL database checker and fixer
#Version 0.19
#To parse logs: :D means it is repairing successfully. :| means did nothing. 

#Check to make sure mysql version is 5.x
if [ `mysql -V | awk '{print $5}' | cut -d "." -f -1` == "5" ]
  then
  echo "You have MySQL 5 or an equivalent :D" | $log
  else echo "you don't have MySQL 5! don't run this >.>" | $log; break
fi
#ask because this takes forever D:
echo -e "Would you like to check space for backups? y for yes"
read checkspace
if [ $checkspace == "y" ]; then
  datadir=`grep datadir /etc/my.cnf | sed s/"datadir="//g`
  echo "Space left is:" `df -h | awk '{print $4}' | head -n2 | tail -n1` "and space MySQL takes up is:" `du -sh $datadir` | $log
fi
echo -e "Would you like to make backups? y for yes"
read backups
if [ $backups == "y" ]; then
  thedate=`date | sed -e s/" "/_/g`;
  mkdir -p /home/sqldumps/$thedate; 
  cd /home/sqldumps/$thedate; 
  for i in $(mysql -BNe 'show databases'| grep -v _schema); do `mysqldump $i > ./$i.sql` ; echo "we have backed up "$i | $log ;done
fi
echo -e "Would you like to take a logfile?"
read logs
if [ $logs == "y" ]; then
  log=">> /root/databasechecklog.txt"
  else log=""
fi
echo "Actually running MyISAM check? y for yes"
read myisam
echo "Actually running InnoDB alter table? y for yes"
read innodb
echo "MyISAM: $myisam and InnoDB: $innodb" >> /root/databasechecklog.txt
#for loop, grab all the databases
for database in $(mysql -e "SHOW DATABASES;"|tail -n+2); do
#for each database, grab all the tables
  for table in $(mysql -e "use $database; show tables;" | tail -n+2); do
#find the type of engine the table is running in
     tabletype=`mysql -e "SELECT ENGINE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='$table' AND TABLE_SCHEMA='$database';" | tail -n+2`
#check to see which table and fix it with a preferred method for each, or spout information
    if [ $tabletype == "InnoDB" ]; then
         if [ $innodb == y ]; then
              echo "$table in $database is InnoDB, rebuilding with alter table command :D" $log
              mysql -e "use $database; ALTER TABLE $table ENGINE = InnoDB" $log
              else echo "$table in $database is InnoDB, doing nothing - disabled :|" $log
         fi
    elif [ $tabletype == "MyISAM" ]; then
         if [ $myisam == y ]; then
              echo "$table in $database is MyISAM, repairing with mysqlcheck :D" $log
              mysqlcheck --auto-repair --optimize $database $table $log
              else echo "$table in $database is MyIsam, doing nothing - disabled :|" $log
         fi 
    elif [ $tabletype == "MERGE" ]; then
         echo "$table in $database is MERGE, checking table :D if you need to fix it might wanna run a UNION command? That's totes beyond me though, I just check tables and stuff." $log
         mysql -e "use $database; CHECK TABLE $table" $log
    else echo "$table in $database has tabletype $tabletype and is not anything I actively fix. :? Not altering." $log
    fi
  done
done
