#MySQL database checker and fixer
#Sam Felshman
#Version 0.1

#Check to make sure mysql version is 5.x
if [ `mysql -V | awk '{print $5}' | cut -d "." -f -1` == "5" ]
then
echo "You have MySQL 5 or an equivalent! :D"
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
     elif [ $tabletype == "MEMORY" ]
     then
         echo "$table in $database is MEMORY and is in memory, we cannae help :| it's fast though :0 and deletes itself on any restart so if you're having any issueswith it you could do that I guess, or dump/recreate"
     elif [ $tabletype == "MERGE" ]
     then
         echo "$table in $database is MERGE, checking table :3 if you need to fix it might wanna run a UNION command? That's totes beyond me though, I just check tables and stuff."
         mysql -e "use $database; CHECK TABLE $table"
     elif [ $tabletype == "FEDERATED" ]
     then
         echo "This table is hosted off-server. /whoa/ D: zomg. May wanna fix it over there but I don't check that noise"
     elif [ $tabletype == "BDB" ] || [ $tabletype == "EXAMPLE" ] || [ $tabletype == "ARCHIVE" ] || [ $tabletype == "PERFORMANCE_SCHEMA" ] || [ $tabletype == "CSV" ] || [ $tabletype == "BLACKHOLE" ]
     then
         echo "$table in $database is something old or static, oh. Not altering @.@ if you wanna mess with this, do it on your own damn time."
     else
         echo "$table in $database is not anything I recognize. :? Not in http://dev.mysql.com/doc/refman/5.0/en/storage-engines.html . Not altering."
     fi
  done
done
else
    echo "You don't have MySQL 5 or an equivalent D:"
fi
