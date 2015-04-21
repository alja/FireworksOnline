#!/bin/bash

kinit -R

MAIL_LIST=olivito@cern.ch
#MAIL_LIST=olivito@cern.ch,gzevi@cern.ch,cerati@cern.ch

#source /afs/cern.ch/project/eos/installation/cms/etc/setup.sh
EOS_PATH=/eos/cms/store/group/visualization/

EOS_COMMAND=/afs/cern.ch/project/eos/installation/0.3.84-aquamarine/bin/eos.select

# use eos quota command to see what fraction of our quota is being used
CURRENT_USAGE=`$EOS_COMMAND quota | grep -B 1 -A 4 "${EOS_PATH}" | grep "zh" | awk '{print $14;}'`

# cleanup threshold
MAX_USAGE=50.0

echo "current usage: $CURRENT_USAGE"
echo "max usage: $MAX_USAGE"
CHECK=`echo $CURRENT_USAGE'>'$MAX_USAGE | bc -l`

if [ $CHECK -eq 1 ]; then
    echo "Over cleanup threshold! Taking action."
else
    echo "Under cleanup threshold. Exiting."
    echo "usage at $CURRENT_USAGE% for $EOS_PATH" | mail -s "EOS visualization space: no cleanup needed" $MAIL_LIST
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
    echo "$EOS_COMMAND rm $f_clean"
    $EOS_COMMAND rm $f_clean
done

# find directories which are now empty
DEL_DIRS=`$EOS_COMMAND find -d ${EOS_PATH} | grep "${MATCH_STRING}" | grep "ndir=0 nfiles=0"  | awk '{print $1;}'`

# remove empty directories
for d in $DEL_DIRS; do
    echo "$EOS_COMMAND rmdir $d"
    $EOS_COMMAND rmdir $d
done

# check quota again
USAGE_AFTER_DEL=`$EOS_COMMAND quota | grep -B 1 -A 4 "${EOS_PATH}" | grep "zh" | awk '{print $14;}'`
echo "usage after delete: $USAGE_AFTER_DEL"

CHECK_AFTER_DEL=`echo $USAGE_AFTER_DEL'>'$MAX_USAGE | bc -l`

# send mail if still over quota
if [ $CHECK_AFTER_DEL -eq 1 ]; then
    echo "Still over cleanup threshold!! Sending mail."
    echo "usage at $USAGE_AFTER_DEL% after attempted deletion for $EOS_PATH" | mail -s "EOS visualization space: WARNING" $MAIL_LIST
    exit 2
else
    echo "Under cleanup threshold. Hurray!"
    echo "usage at $USAGE_AFTER_DEL% after deletion for $EOS_PATH" | mail -s "EOS visualization space: cleanup successful" $MAIL_LIST
fi

exit 1