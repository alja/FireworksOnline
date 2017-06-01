#!/bin/bash

timeLeft=""

if [ "$1" == "" ]; then
    echo "Usage: ./vipMode.sh [time to stay in vipMode (minutes)]"
    exit
else
    echo "Will run vipMode for $1 minutes starting on `date`"
    timeLeft=${1}
fi

pid=-1

stopStart() {
    /home/vis/Fireworks/bin/fireworksOnlineSystem /home/vis/Fireworks stop   
    /home/vis/Fireworks/bin/fireworksOnlineSystem /home/vis/Fireworks start
}

findPid() {
    pid=`ps aux | grep latestFile.pl | grep Fireworks | awk '{print $2}'`
    if [ "$pid" == "" ]
    then	
	echo "could not find latestFile.pl among running processes"
    fi
}

killLatestFile() {
    findPid
    if  [ "$pid" == "" ]
    then
	echo "cannot kill what I cannot find"
    else
	echo "killing latestFile process ${pid}"
	kill ${pid}
    fi
}

restartLatestFile(){
    pid=-1
    findPid
    if  [ "$pid" == "" ]
    then
	echo "Restarting latestFile.pl"
	date=`date -I`
	cp  Fireworks/log/latestFile.log  Fireworks/log/latestFile{$date}.log
	nohup Fireworks/bin/latestFile.pl &> Fireworks/log/latestFile.log &	
    else
	echo "latestFile.pl is still running, no need to restart it"
    fi
}
resetNormalMode() {
    restartLatestFile
    cat ~/Log/LastFileBeforeVIP > ~/Log/LastFile
    #    stopStart
}


trap resetNormalMode INT

cd ~

echo "vipMode.sh started on machine 40, time set to $1 minutes" | mail -s "P5: vipMode has started" gzevi@cern.ch giuseppe.cerati@cern.ch olivito@cern.ch
killLatestFile
echo "Add VIP file to Log/LastFile"
cp ~/Log/LastFile ~/Log/LastFileBeforeVIP
#echo ~/ttbarRelVal2.root > ~/Log/LastFile
echo ~/VipData/run254790_ls0100to0150_streamEvDOutput2_dqmcluster.root  > ~/Log/LastFile
#test echo ~/RelVal900.root  > ~/Log/LastFile
#stopStart
if [ $timeLeft -gt 240 ]
then
    echo "Time ${timeLeft} is larger than 4 hours. Setting vipMode to 4 hours."
    timeLeft=239
fi
# Trick to switch files every 80 minutes (current ttbar file has 1200 events, so around 100 minutes
setLink=0
while [ $timeLeft -gt 40 ]; do
    sleep 40m
    timeLeft=`expr $timeLeft - 40`    
    if [ $setLink = 0 ]
    then
	echo "Pushing linked ttbar file to loop. Time remaining is ${timeLeft}"
#	echo ~/ttbarRelVal2_link.root > ~/Log/LastFile
	echo ~/VipData/run254790_ls0100to0150_streamEvDOutput2_dqmcluster_link.root > ~/Log/LastFile
#test	echo ~/RelVal900.root  > ~/Log/LastFile
	setLink=1
    else
	echo "Pushing original ttbar file to loop. Time remaining is ${timeLeft}"
#	echo ~/ttbarRelVal2.root > ~/Log/LastFile
	echo ~/VipData/run254790_ls0100to0150_streamEvDOutput2_dqmcluster.root > ~/Log/LastFile
#test	echo ~/RelVal900.root  > ~/Log/LastFile
	setLink=0
    fi
done
sleep ${timeLeft}m
echo "Done with VIP mode. Reset now."

resetNormalMode
echo "Finished resetting. Email report and exit."
echo "vipMode.sh stopped cleanly on machine 40" | mail -s "P5: vipMode stopped" gzevi@cern.ch giuseppe.cerati@cern.ch olivito@cern.ch





