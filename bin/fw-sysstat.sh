#!/bin/bash
set -x
recmail=alja.mrak.tadel@cern.edu
host=`hostname`
pid=`ps --no-headers -opid -C "cmsShow.exe"`


############################################
# MEMORY ###################################
############################################
export memLimit=1000000;
#export memLimit=3000000;
memMSG=`pmap $pid |tail -1 |  perl -ne 'if (~/total\s+(\d+)K/){ $mem=$1; if ($mem > $ENV{memLimit}) {printf "memory usage exceed\n  ${mem}K > $ENV{memLimit}K\n"};  }'`
if [ -n "$memMSG" ]
then
   echo $memMSG
   echo $memMSG |  mail -s "Memory usage $host" "$recmail"
fi

############################################
# CPU    ###################################
############################################
export cpuLimit=90;
cpuMSG=`ps -p $pid -o %cpu | tail -1 | perl -e '{ $cpu=$_; chomp $cpu; if ($cpu > $ENV{cpuLimit}) {print "cpu usage exceed\n, $cpu > $ENV{cpuLimit} \n"} }'`
if [ -n "$cpuMSG" ]
then
   echo $cpuMSG
   echo $cpuMSG |  mail -s "CPU usage $host" "$recmail"
fi


############################################
# DISK    ##################################
############################################
export diskLimit=90

for i in /home /eventdisplay
do
data=$i
diskMSG=`df $data | tail -1 |  perl -ne 'if (~/\s+(\d+)\%\s+(.+)$/){ $disk=$1; $loc=$2 ;if ($disk > $ENV{diskLimit}) {print "disku sage exceed\n $disk > $ENV{diskLimit}\n"};  }'`
if [ -n "$diskMSG" ]
then
    echo $diskMSG
    echo $diskMSG  | mail -s "disk usage $host $data" "$recmail"
fi
done
