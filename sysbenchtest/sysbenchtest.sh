#!/bin/bash

# Kester Riley
# kesterriley@hotmail.com
# github.com/kesterriley


# import variables
source ./.sysbench.cfg


prepareDatabase() {
  echo "... Droping and creating datsbase"
  mariadb -u$lv_username -p$lv_password --host="$lv_host" --port=$lv_port -e "DROP DATABASE IF EXISTS $lv_database"
  mariadb -u$lv_username -p$lv_password --host="$lv_host" --port=$lv_port -e "CREATE DATABASE $lv_database"
  echo "... Dropped Database"
}

preparesystem() {
  [[ ! -d results ]] &&  mkdir results || echo "Results directory already exists"
}

prepareoutfile() {
  outputfile="results/"$1"-"$lv_table_size"-"$(date +"%Y_%m_%d_%HH%MM")".csv"
  echo "Threads|Read|Write|Other|Total|Transactions|Transactions per second|Ignored Errors|Ignored Errors per sec|Reconnects|Reconnects per sec|Min|Avg|Max|95th" > $outputfile
}

prepareSysBench() {
  echo "... preparing SysBench"
  sysbench $1 --db-driver=mysql --table-size=$lv_table_size --mysql-user=$lv_username --mysql-password=$lv_password --mysql-db=$lv_database --mysql-host=$lv_host --mysql-port=$lv_port --threads=12 prepare
  echo "... Sysbench prepared"
}

runSysBench() {
  echo "... running SysBench"
  sysbench $1 --db-driver=mysql --table-size=$lv_table_size --mysql-user=$lv_username --mysql-password=$lv_password --mysql-db=$lv_database --mysql-host=$lv_host --mysql-port=$lv_port  --threads=$2 run > ./results/$1-$2.log
  echo "... Sysbench run completed"
}

cleanSysBench() {
  echo "... clearing up SysBench"
  sysbench $1 --db-driver=mysql --mysql-user=$lv_username --mysql-password=$lv_password --mysql-db=$lv_database --mysql-host=$lv_host --mysql-port=$lv_port cleanup
  echo "... Sysbench cleared up"
}

makecsv () {
  echo "... preparing CSV"

  #SOSarlacii - 2023-0112: ??? egrep is deprecated in favour of 'grep -E'?
  cat  ./results/$1-$2.log | egrep " cat|threads:|transactions|read:|write:|other:|total:|errors:|reconnects:|min:|avg:|max:|percentile:"| tr -d "\n"| sed 's/Number of threads: //g' | sed 's/\[/\n/g' | sed 's/[A-Za-z\/]\{1,\}://g' | sed 's/ \.//g' | sed -e 's/read\/write//g' -e 's/95th//g' -e 's/per sec.)//g' -e 's/ms//g' -e 's/ignored//g' -e 's/(//g' -e 's/^.*cat //g' | sed 's/ \{1,\}/\|/g' >> $outputfile
  #SOSarlacii - 2023-0112: Add carriage return to end each line, else only the first thread number is printed, and the rest are swallowed, making one long line.
  printf "\n" >> $outputfile
  echo "... Created CSV"
}

  preparesystem
  prepareDatabase

#SOSarlacii - 2023-0112: Best practice is $() instead of back ticks
for TESTTORUN in $(echo $lv_test_to_run)
do
  prepareoutfile $TESTTORUN
  echo "Running $TESTTORUN"
  for THREAD in $(echo $lv_threads)
  do
    echo "Running $TESTTORUN for $THREAD threads"
    prepareSysBench $TESTTORUN
    runSysBench $TESTTORUN $THREAD
    makecsv $TESTTORUN $THREAD
    cleanSysBench $TESTTORUN
  done
done
