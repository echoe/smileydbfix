#MySQL database checker and fixer https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh
#Version 0.31
#Please keep line 2 in place for the version check.
#To run (not as script): bash <(curl https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh)
#To parse logs: :D means it is repairing successfully. :| means that it did nothing. :? means that it doesn't deal with it.
#if you'd like, change variables here! Just uncomment and switch to whatever.
runasscript=n
checkspace=y
backups=y
myisam=y
innodb=y
updatecheck=y
myisamcheck=yes
#initial clearing things up. first, get date for backups and logmoving
thedate=`date | sed -e s/" "/_/g`
#if a log exists, move it! we don't want you, log :( (this actually works)
if [ -a /tmp/dblogfile ]; then
  mv /tmp/dblogfile /tmp/dblogfile$thedate
fi
#if this is being run as a script, check for an update before running [untested! :/]
if [ $runasscript = "y" ]; then
  #grab
  localversion=`sed '2q;d' $0 | awk '{print $2}'`
  remoteversion=`wget https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh | head -n2 | tail -n1 | awk '{print $2}'`
  if [ $localversion != $remoteversion ]; then
    echo "You have an old version! Please download the latest version from https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh ." | tee -a /tmp/dblogfile
  fi
fi
#This is taken from mysqltuner and counts the number of fractured tables. :)
#Here are the checkspace and backup functions, since otherwise I'd have to call them twice
checkspacefunction() {
  datadir=`grep datadir /etc/my.cnf | sed s/"datadir="//g`
  echo "Space left is:" `df -h | awk '{print $4}' | head -n2 | tail -n1` "and space MySQL takes up is:" `du -sh $datadir` | tee -a /tmp/dblogfile
}
backupfunction() {
  mkdir -p /home/sqldumps/$thedate; 
  cd /home/sqldumps/$thedate; 
  for i in $(mysql -BNe 'show databases'| grep -v _schema); do 
    `mysqldump $i > ./$i.sql` | tee -a /tmp/dblogfile
    echo "We have backed up $i. Yay! :D" | tee -a /tmp/dblogfile
  done
}
#unused as of yet
getfractured() {
  $1=`mysql -Bse "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY';"`
}
#Welcome!
echo "Welcome to databasecheck.sh!" | tee -a /tmp/dblogfile
#Check to make sure that the mysql [or mariadb] version is 5.x . Also, reset the logs [tee, not tee -a]
if [ `mysql -V | awk '{print $5}' | cut -d "." -f -1` == "5" ]; then
  echo "You have MySQL 5 or an equivalent :D" | tee -a /tmp/dblogfile
    starttables=`mysql -Bse "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY';"`
  echo "Current number of fractured tables: $starttables" | tee -a /tmp/dblogfile
  else echo "you don't have MySQL 5! don't run this >.>" | tee -a /tmp/dblogfile; break
fi
#If running as script, skip this section. else, run this section.
if [ $runasscript = n ]; then
  #Ask because this takes forever D:
  echo -e "Would you like to check space for backups? y for yes"
  read checkspace
  #this and backups are oneliners since they're simpler to read and shorter that way.
  if [ $checkspace == "y" ]; then checkspacefunction; fi
  echo -e "Would you like to make backups? y for yes"
  read backups
  if [ $backups == "y" ]; then backupfunction; fi
  #Which checks do you want to run? May include option to skip these and run as a script with variables later. [if variables = on, skip this section]
  echo "Would you actually like to run MyISAM mysqlchecks (no downtime)? Type y for yes"
  read myisam
  echo "Would you actually like to run InnoDB alter table commands? Type y for yes"
  read innodb
  #Check for MyISAM with 'yes' and not 'y' to be sure that this is needed.
  echo "Would you actually like to run the MyISAMcheck MySQL check? Type yes for yes"
  read myisamcheck
  #Check this again just to make absolutely, /absolutely/ sure.
  if [ $myisamcheck == yes ]; then
    echo "Are you sure? This will, again, cause MySQL downtime! Please type yes again to confirm."
    read myisamcheck
  fi
#this bottom fi is just for the 'skip setting variables' part of the script
  else echo "Skipping variable check, they are set in the script!" | tee -a /tmp/dblogfile
  if [ $checkspace == "y" ]; then checkspacefunction; fi
  if [ $backups == "y" ]; then backupfunction; fi
fi
#echo the choices into the logfile when the logfile works
echo "Backups=" $backups, "MyISAM=" $myisam, "InnoDB=" $innodb | tee -a /tmp/dblogfile
#for loop, grab all the databases
for database in $(mysql -e "SHOW DATABASES;"|tail -n+2); do
#for each database, grab all the tables
  for table in $(mysql -e "use $database; show tables;" | tail -n+2); do
#find the type of engine the table is running in
    tabletype=`mysql -e "SELECT ENGINE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='$table' AND TABLE_SCHEMA='$database';" | tail -n+2`
#check to see which table it is, and fix it with a preferred method for each as needed
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
        else echo "$table in $database is MyISAM, doing nothing - disabled :|" | tee -a /tmp/dblogfile
      fi
    elif [ $tabletype == "MERGE" ]; then
      echo "$table in $database is MERGE, checking table :D Maybe you can fix with a UNION command, but I don't do that." | tee -a /tmp/dblogfile
      mysql -e "use $database; CHECK TABLE $table" | tee -a /tmp/dblogfile
      else echo "$table in $database has tabletype $tabletype and is not anything I actively fix. :? Not altering." | tee -a /tmp/dblogfile
    fi
  done
done
#run the myisamcheck if needed.
if [ $myisamcheck == "yes" ]; then
  #Tell the user what's up.
  startmyisamtables=`mysql -Bse "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY';"`
  echo "Current number of fractured tables: $startmyisamtables" | tee -a /tmp/dblogfile
  echo "MyISAM check enabled, turning off MySQL and running now!" | tee -a /tmp/dblogfile
  #Record the date [to get total downtime], then turn off MySQL for the checks.
  starttime=`date | awk '{print $2,$3,$4}'`
  service mysql stop && chmod -x /usr/bin/mysql && chmod -x /usr/sbin/mysqld | tee -a /tmp/dblogfile
  myisamchk --safe-recover --key_buffer_size=1G --read_buffer_size=300M --write_buffer_size=300M --sort_buffer_size=2G /var/lib/mysql/*/*.MYI | tee -a /tmp/dblogfile
  chmod +x /usr/bin/mysql && chmod +x /usr/sbin/mysqld && service mysql start | tee -a /tmp/dblogfile
  endtime=`date | awk '{print $2,$3,$4}'`
  echo "The total time your MySQL was down was from $starttime to $endtime." | tee -a /tmp/dblogfile
  finalfracturedtables=`mysql -Bse "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY';"`
  echo "The MyISAM check made your fractured tables number go from $startmyisamtables to $finalfracturedtables." | tee -a /tmp/dblogfile
fi
#Tell them about the logs now that it's run!
finalfracturedtables=`mysql -Bse "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY';"`
echo "Final number of fractured tables: $finalfracturedtables" | tee -a /tmp/dblogfile
echo "Total change: from $starttables to $finalfracturedtables" | tee -a /tmp/dblogfile
echo "Finished! If you're wondering exactly what happened, logs for this are created in /tmp/dblogfile." | tee -a /tmp/dblogfile
