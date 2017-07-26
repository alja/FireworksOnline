#!/bin/bash

kinit -R

MAIL_LIST=olivito@cern.ch
#MAIL_LIST=olivito@cern.ch,gzevi@cern.ch,cerati@cern.ch

#source /afs/cern.ch/project/eos/installation/cms/etc/setup.sh
EOS_PATH=/eos/cms/store/group/visualization/

## command has to be on afs for acron to see it correctly (?)
EOS_COMMAND=/afs/cern.ch/project/eos/installation/scripts/bin/eos.select

# use eos quota command to see what fraction of our quota is being used
CURRENT_DISK_USAGE=`$EOS_COMMAND quota | grep -B 1 -A 4 "${EOS_PATH}" | grep "zh" | awk '{print $14;}'`

# check number of files
#CURRENT_FILE_USAGE=`$EOS_COMMAND find -f ${EOS_PATH} | wc -l`
CURRENT_FILE_USAGE=`$EOS_COMMAND find --count -f ${EOS_PATH} | awk '{print $1;}' | awk -F'=' '{print $2;}'`

# cleanup thresholds
# hard limit on files is 1000000 (1M), clean up at 800k
MAX_DISK_USAGE=80.0
MAX_FILE_USAGE=800000

echo ""
echo "current disk usage: $CURRENT_DISK_USAGE"
echo "max disk usage: $MAX_DISK_USAGE"
echo ""
echo "current file usage: $CURRENT_FILE_USAGE"
echo "max file usage: $MAX_FILE_USAGE"
echo ""

CHECK_DISK=`echo $CURRENT_DISK_USAGE'>'$MAX_DISK_USAGE | bc -l`

if [ $CHECK_DISK -eq 1 ] || [ $CURRENT_FILE_USAGE -gt $MAX_FILE_USAGE ]; then
    echo "Over cleanup threshold! Taking action."
else
    echo "Under cleanup threshold. Exiting."
    echo "usage at $CURRENT_DISK_USAGE% for $EOS_PATH" | mail -s "EOS visualization space: no cleanup needed" $MAIL_LIST
    exit 0
fi

# retention times, in days
RETENTION_TIME=3

MATCH_STRING=/run

# finding old directories doesn't seem to work on EOS
# instead find and delete old files
# then check for empty directories and remove them

# find files older than RETENTION_TIME
DEL_FILES=`$EOS_COMMAND find -f -ctime +${RETENTION_TIME} ${EOS_PATH} | grep "${MATCH_STRING}" | awk '{print $1;}'`

# remove old files
for f in $DEL_FILES; do
    # remove "path=" from file name, if present
    f_clean=${f/path=/}
    #echo "$EOS_COMMAND rm $f_clean"
    $EOS_COMMAND rm $f_clean
done

# find directories which are now empty
DEL_DIRS=`$EOS_COMMAND find -d ${EOS_PATH} | grep "${MATCH_STRING}" | grep "ndir=0 nfiles=0"  | awk '{print $1;}'`

# remove empty directories
for d in $DEL_DIRS; do
    #echo "$EOS_COMMAND rmdir $d"
    $EOS_COMMAND rmdir $d
done

# check quota again
DISK_USAGE_AFTER_DEL=`$EOS_COMMAND quota | grep -B 1 -A 4 "${EOS_PATH}" | grep "zh" | awk '{print $14;}'`
echo "disk usage after delete: $DISK_USAGE_AFTER_DEL"
FILE_USAGE_AFTER_DEL=`$EOS_COMMAND find -f ${EOS_PATH} | wc -l`
echo "file usage after delete: $FILE_USAGE_AFTER_DEL"

CHECK_AFTER_DEL=`echo $DISK_USAGE_AFTER_DEL'>'$MAX_DISK_USAGE | bc -l`

# send mail if still over quota
if [ $CHECK_AFTER_DEL -eq 1 ] || [ $FILE_USAGE_AFTER_DEL -gt $MAX_FILE_USAGE ] ; then
    echo "Still over cleanup threshold!! Sending mail."
    echo "usage at $DISK_USAGE_AFTER_DEL% after attempted deletion for $EOS_PATH" | mail -s "EOS visualization space: WARNING" $MAIL_LIST
    exit 2
else
    echo "Under cleanup threshold. Hurray!"
    echo "usage at $DISK_USAGE_AFTER_DEL% after deletion for $EOS_PATH" | mail -s "EOS visualization space: cleanup successful" $MAIL_LIST
fi

exit 1
