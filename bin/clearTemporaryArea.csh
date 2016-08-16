#!/bin/tcsh 

#
# so: try and have files lasting at least $retention_time; 
#
#
# dquota is the quota of the area
# minfree must be the minimum free area to complete current operations
#

# if disk used more than $maxdisk, delete the oldest ones respecting the previous requirement
# if disk used more than $maxdisk, delete the oldest ones without respecting the previous requirement, but then send a WARNING
if ($#argv != 1) then
        echo "Usage: $0 <directory>"
        exit 1
endif

set verb=1

set AREA=$1

#
# in hours
#

set retention_time=36
set retention_time2=12

#
# disk quota (in kB)
#
#this is 13 GB: 12882980

set dquota=150000000

#
# minfree (in kB)
#
set minfree=50000000

@ maxdisk= $dquota - $minfree

if ($verb) then
    echo Setting maxdisk to $maxdisk. Date is `date`
endif
#
# get disk used
#
cd $AREA
#fs flush .
#fs flush ./Log
set used=`du -s |awk '{print $1}'`

if ($verb) then
    echo Used disk is $used
endif


if ($used < $maxdisk) then
#
# nothing to do
#
if ($verb) then
    echo Exit with code 0
endif

exit 0
endif

#/usr/sbin/tmpwatch --verbose -d --mtime $retention_time .
# first test - see if you can clean applying retention time
#  also allow directories to be deleted in this first pass
if ($used > $maxdisk) then
if ($verb) then
    echo Running tmpwatch
endif
# /usr/sbin/tmpwatch --verbose -x ".snapshot" -d --mtime $retention_time . 
 /usr/sbin/tmpwatch --verbose -x ".snapshot" --mtime $retention_time . 
endif
#
# now look whether situation is good
#
set newused=`du -s |awk '{print $1}'`

if ($verb) then
    echo Now used is $newused
endif

if ($newused < $maxdisk) then
#
# I am happy, I bail out
# exit 2 = i had to delete, but just stuff I could delete
exit 2
endif
#
# try with retentiontime2 before going on
# do not allow directories to be deleted here
#
 /usr/sbin/tmpwatch --verbose -x ".snapshot" -d --mtime $retention_time2 .
set newused=`du -s |awk '{print $1}'`
if ($newused < $maxdisk) then
#
# I am happy, I bail out
# exit 2 = i had to delete, but just stuff I could delete
exit 2
endif


#
# else, delete files in order of age, one by one
#
set oldfile="aaa"
while ($newused > $maxdisk)
 #
 # find the oldest file
 set file=`ls -t1 */*root|tail -1`
 if ($file =="") then
    echo Not enough files to kill, I bail out
    exit 4 
 endif
 if ($file ==$oldfile) then
    echo something fishy, probably a file cannot be deleted, I bail out
    exit 5
 endif
 if ($verb) then
    echo Deleting $file  
endif
 rm -f $file
 set $oldfile=$file
 #calculate new disk free
 set newused=`du -s |awk '{print $1}'`
if ($verb) then
    echo Now free is $newused 
endif
#
end

#exit three means I had to delete stuff not expired
exit 3

#
