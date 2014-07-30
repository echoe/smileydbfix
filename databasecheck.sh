#MySQL database checker and fixer https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh
#Version 0.40
#Added: single database check functionality! (needs an additional check or two ...), customizable MyISAM check
#Changed: order of variables (it asks if you want to fix tables before it asks if you want backups so you can go SPACE SPACE SPACE)
#Please keep line 2 in place for the version check. Version 0,34: better script functionality!
#To run (not as script): bash <(curl https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh)
#To parse logs: :D means it is repairing successfully. :| means that it did nothing. :? means that it doesn't deal with it.
#if you'd like, change variables here! Just uncomment and switch to whatever. By default this is set to take zipped backups, then fix.
#First we set variables that aren't beholden to functions!
#This grabs the datadir using horrible cut commands. I want to switch this to sed, or something more dependable, but this should do for now and into the future.
#Our data directory is almost always /var/lib/mysql anyways [and the config file is almost always /etc/my.cnf]
datadir=`ps aux|grep [m]ysql | grep -v safe | cut -d"t" -f2 | cut -d"=" -f2 | cut -d" " -f1`
runasscript=n
myisam=y
innodb=y
checkspace=n
backups=z
#updatecheck is untested and therefore off as you generally won't want it on..
updatecheck=n
#myisamcheck needs to be switched to yes to run, not y. this is for safety.
myisamcheck=no
#Date for backups and logmoving
thedate=`date | sed -e s/" "/_/g`
#Here are the functions for the script, which all have to be declared before the script itself.
checkspacefunction() {
  echo "Space left is:" `df -h | awk '{print $4}' | head -n2 | tail -n1` "and space MySQL takes up is:" `du -sh $datadir` | tee -a /tmp/dblogfile
}
#this takes a variable 'backuptype' that determines if these are zipped or not
backupfunction() {
  backuptype=$1
  mkdir -p /home/sqldumps/$thedate;
  cd /home/sqldumps/$thedate;
  for i in $(mysql -BNe 'show databases'| grep -v _schema); do
    if [[ $backuptype == y ]]; then
      `mysqldump $i > ./$i.sql` | tee -a /tmp/dblogfile; echo "We have backed up $i. Yay! :D" | tee -a /tmp/dblogfile
    elif [[ $backuptype == z ]]; then
      `mysqldump $i | gzip > ./$i.sql` | tee -a /tmp/dblogfile; echo "We have backed up $i. Yay! :D" | tee -a /tmp/dblogfile
    fi
  done
}
#This is used to get the number of fractured tables and is returned by setting a variable to $(getfractured)
getfractured() {
  echo `mysql -Bse "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema','mysql') AND Data_free > 0 AND NOT ENGINE='MEMORY';"`
}
#This was changed to a function in 0.38. This function checks the tables! please call it like so:
#fixtables $database $table
fixtables() {
    database=$1
    table=$2
    tabletype=`mysql -e "SELECT ENGINE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='$table' AND TABLE_SCHEMA='$database';" | tail -n+2`
#check to see which table it is, and fix it with a preferred method for each as needed
    if [ $tabletype == "InnoDB" ]; then
#double brackets are so this won't throw errors if you don't input a value upon querying (i.e. just hit enter)
      if [[ $innodb == y ]]; then
        echo "$table in $database is InnoDB, rebuilding with alter table command :D" | tee -a /tmp/dblogfile
        mysql -e "use $database; ALTER TABLE $table ENGINE = InnoDB" | tee -a /tmp/dblogfile
        else echo "$table in $database is InnoDB, doing nothing - disabled :|" | tee -a /tmp/dblogfile
      fi
    elif [ $tabletype == "MyISAM" ]; then
      if [[ $myisam == y ]]; then
        echo "$table in $database is MyISAM, repairing with mysqlcheck :D" | tee -a /tmp/dblogfile
        mysqlcheck --auto-repair --optimize $database $table | tee -a /tmp/dblogfile
        else echo "$table in $database is MyISAM, doing nothing - disabled :|" | tee -a /tmp/dblogfile
  fi
  elif [ $tabletype == "MERGE" ]; then
    echo "$table in $database is MERGE, checking table :D Maybe you can fix with a UNION command, but I don't do that." | tee -a /tmp/dblogfile
    mysql -e "use $database; CHECK TABLE $table" | tee -a /tmp/dblogfile
  else echo "$table in $database has tabletype $tabletype and is not anything I actively fix. :? Not altering." | tee -a /tmp/dblogfile
fi
}
starttables=$(getfractured)
versioncheck=`mysql -V | awk '{print $5}' | cut -d "." -f -1`
#Welcome! This is the actual beginning of the script. First, checks to ensure that we should be starting the script ...
#if a log exists, move it! we don't want you, old log! go away :(
if [ -a /tmp/dblogfile ]; then
  mv /tmp/dblogfile /tmp/dblogfile$thedate
fi

#if this is being run as a script, check for an update before running [untested!]
if [ $runasscript = "y" ]; then
  #grab
  if [ updatecheck = "y" ]; then
    localversion=`sed '2q;d' $0 | awk '{print $2}'`
    remoteversion=`wget https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh | head -n2 | tail -n1 | awk '{print $2}'`
    if [ $localversion != $remoteversion ]; then
      echo "You have an old version! Please download the latest version from https://raw.github.com/echoe/smileydbfix/master/databasecheck.sh ." | tee -a /tmp/dblogfile
    fi
  fi
fi

#This is where the script actually does things.

echo "Welcome to databasecheck.sh!" | tee -a /tmp/dblogfile
echo "Current number of fractured tables: $starttables" | tee -a /tmp/dblogfile
#Check to make sure that the mysql [or mariadb] version is 5.x or 10.x [fixed!]. Also, reset the logs [tee, not tee -a]
if [[ $versioncheck == "5" || $versioncheck == "10" ]]; then
  echo "You have MySQL 5 or MariaDB 10 :D" | tee -a /tmp/dblogfile
  else echo "you don't have MySQL 5! don't run this >.>" | tee -a /tmp/dblogfile; exit
fi
#If running as script, skip this section. else, run this section.
if [ $runasscript = n ]; then
  echo -e "If you would like to fix a specific database, please type it now. (Watch out for typing errors!)"
  read database
  if [[ $database != "" ]]; then
    if [[ `mysqlshow |grep "$database"` ]]; then
      echo -e "Please provide the table if you want to fix a specific table! (Watch out for typing errors!)"
      read table
      if [[ $table != "" ]]; then
        fixtables $database $table
      else for table in $(mysql -e "use $database; show tables;" | tail -n+2); do
        fixtables $database $table
      done
      fi
      #Exits the script here so it doesn't try to check all the tables afterwards >.>
      echo "Thanks for using databasecheck.sh . Have a good day. :D"; exit
    fi
  fi
  #If you don't want a single check, which checks do you want to run? May include option to skip these and run as a script with variables later. [if variables = on, skip this section]
  echo "Would you actually like to run MyISAM mysqlchecks (no downtime)? Type y for yes"
  read myisam
  echo "Would you actually like to run InnoDB alter table commands? Type y for yes"
  read innodb
  #Check for MyISAM with 'yes' and not 'y' to be sure that this is needed.
  echo "Would you actually like to run the MyISAMcheck MySQL check? Type yes for yes"
  read myisamcheck
  #Check this again just to make absolutely, /absolutely/ sure.
  if [ "$myisamcheck" == yes ]; then
    echo "Are you sure? This will, again, cause MySQL downtime! Please type yes again to confirm."
    read myisamcheck
    #get settings
    if [ "$myisamcheck" == yes ]; then
      echo "Well, you'll want to change the settings then most likely. Here are the options."
      keybuffersize="1G"
      readbuffersize="300M"
      writebuffersize="300M"
      sortbuffersize="2G"
      echo "Key buffer size? Default 1G"
      read keybuffersize
      echo "Read buffer size? Default 300M"
      read readbuffersize
      echo "Write buffer size? Default 300M"
      read writebuffersize
      echo "Sort buffer size? Default 2G"
      read sortbuffersize
      echo "Data directory? Default " $datadir
      read datadir
    fi
  fi
  #Ask because this takes forever D:
  echo -e "Would you like to check space for backups? y for yes"
  read checkspace
  #this and backups are oneliners since they're simpler to read and shorter that way. 
  #This is at the back but is done first because generally people just want to fix tables.
  if [ "$checkspace" == "y" ]; then checkspacefunction; fi
  echo -e "Would you like to make backups? y for yes. z for zipped backups"
  read backups
  if [[ "$backups" == "y" || "$backups" == "z" ]]; then backupfunction $backups; fi
else echo "Skipping variable check, they are set in the script!" | tee -a /tmp/dblogfile
  if [ $checkspace == "y" ]; then checkspacefunction; fi
  if [[ "$backups" == "y" || "$backups" == "z" ]]; then backupfunction $backups; fi
  #other variables are read within the script
fi
#set date. this needs to be done now as answering the questions can take time this measures innodb/myisam repair time.
thestarttime=`date | awk '{print $2,$3,$4}'`
#echo the choices into the logfile.
echo "Backups=" $backups, "MyISAM=" $myisam, "InnoDB=" $innodb | tee -a /tmp/dblogfile
#for loop, grab all the databases
for database in $(mysql -e "SHOW DATABASES;"|tail -n+2); do
#for each database, grab all the tables
  for table in $(mysql -e "use $database; show tables;" | tail -n+2); do
  #run the new function!
    fixtables $database $table
  done
done
#run the myisamcheck if needed.
if [ "$myisamcheck" == "yes" ]; then
  #Tell the user what's up. This also measures MyIsam check start time as it is actual downtime and needs to be read differently
  startmyisamtables=$(getfractured)
  datadir=
  echo "Current number of fractured tables: $startmyisamtables" | tee -a /tmp/dblogfile
  echo "MyISAM check enabled, turning off MySQL and running now!" | tee -a /tmp/dblogfile
  #Record the date [to get total downtime], then turn off MySQL for the checks.
  starttime=`date | awk '{print $2,$3,$4}'`
  service mysql stop && chmod -x /usr/bin/mysql && chmod -x /usr/sbin/mysqld | tee -a /tmp/dblogfile
  #Let's tell the logs what we're running
  echo "Key buffer size=" $keybuffersize, "Read buffer size=" $readbuffersize, "Write buffer size=" $writebuffersize, "Sort buffer size =" $sortbuffersize | tee -a /tmp/dblogfile
  myisamchk --safe-recover --key_buffer_size=$keybuffersize --read_buffer_size=$readbuffersize --write_buffer_size=$writebuffersize --sort_buffer_size=$sortbuffersize $datadir/*/*.MYI | tee -a /tmp/dblogfile
  chmod +x /usr/bin/mysql && chmod +x /usr/sbin/mysqld && service mysql start | tee -a /tmp/dblogfile
  endtime=`date | awk '{print $2,$3,$4}'`
  echo "The total time your MySQL was down was from $starttime to $endtime." | tee -a /tmp/dblogfile
fi
#Tell them about the logs now that it's run!
finalfracturedtables=$(getfractured)
theendtime=`date | awk '{print $2,$3,$4}'`
echo "The total time your MySQL was being checked was from $thestarttime to $theendtime." | tee -a /tmp/dblogfile
echo "Final number of fractured tables: $finalfracturedtables" | tee -a /tmp/dblogfile
echo "Total change: from $starttables to $finalfracturedtables" | tee -a /tmp/dblogfile
echo "Finished! If you're wondering exactly what happened, logs for this are created in /tmp/dblogfile." | tee -a /tmp/dblogfile
