#MySQL database checker and fixer
#Sam Felshman
#Version 0.12

#Check to make sure mysql version is 5.x
if [ `mysql -V | awk '{print $5}' | cut -d "." -f -1` == "5" ]
  then
  echo "You have MySQL 5 or an equivalent :D"
  else echo "you don't have MySQL 5! don't run this >.>"; break
fi

echo -e "Would you like to check space for backups? y for yes"
read checkspace
if [ $checkspace == "y" ]; then
  datadir=`grep datadir /etc/my.cnf | sed s/"datadir="//g`
  echo "Space left is:" `du -sh /home` "and space MySQL takes up is:" `du -sh $datadir`
fi
echo -e "Would you like to make backups? y for yes"
read backups
if [ $backups == "y" ]; then
  thedate=`date`;
  mkdir -p /home/sqldumps/$thedate; 
  cd /home/sqldumps/$thedate; 
  for i in `echo "show databases;" | mysql` ; do `mysqldump $i > ./$i.sql` ; echo "we have backed up "$i ;done
fi
#for loop, grab all the databases
for database in $(mysql -e "SHOW DATABASES;"|tail -n+2)
do
#for each database, grab all the tables
  for table in $(mysql -e "use $database; show tables;" | tail -n+2)
  do
#find the type of engine the table is running in
     tabletype=`mysql -e "SELECT ENGINE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='$table' AND TABLE_SCHEMA='$database';" | tail -n+2`
#check to see which table and fix it with a preferred method for each, or spout information
     if [ $tabletype == "InnoDB" ]
    then
         echo "$table in $database is InnoDB, rebuilding with alter table command :D"
         mysql -e "use $database; ALTER TABLE $table ENGINE = InnoDB"
    elif [ $tabletype == "MyISAM" ]
    then
         echo "$table in $database is MyISAM, repairing with mysqlcheck :D"
         mysqlcheck --auto-repair --optimize $database $table 
    elif [ $tabletype == "MERGE" ]
    then
         echo "$table in $database is MERGE, checking table :3 if you need to fix it might wanna run a UNION command? That's totes beyond me though, I just check tables and stuff."
         mysql -e "use $database; CHECK TABLE $table"
    else
         echo "$table in $database has tabletype $tabletype and is not anything I actively fix. :? Not in http://dev.mysql.com/doc/refman/5.0/en/storage-engines.html . Not altering."
    fi
  done
done
