#!/bin/sh

## my own rsync-based snapshot-style backup procedure
## (cc) marcio rps AT gmail.com

# config vars

SRC="/home/kirkham/" #dont forget trailing slash!
SNAP="/mnt/backup/snapshots"
OPTS="-rltgoi --delay-updates --delete --chmod=a-w"
EXCLUDE="/home/kirkham/scripts/rsync_exclude"
MINCHANGES=20

# run this process with real low priority

ionice -c 3 -p $$
renice +12  -p $$

# sync

rsync --exclude-from=$EXCLUDE $OPTS $SRC $SNAP/latest >> $SNAP/rsync.log

# check if enough has changed and if so
# make a hardlinked copy named as the date

COUNT=$( wc -l $SNAP/rsync.log|cut -d" " -f1 )
if [ $COUNT -gt $MINCHANGES ] ; then
        DATETAG=$(date +%Y-%m-%d)
        if [ ! -e $SNAP/$DATETAG ] ; then
                cp -al $SNAP/latest $SNAP/$DATETAG
                chmod u+w $SNAP/$DATETAG
                mv $SNAP/rsync.log $SNAP/$DATETAG
               chmod u-w $SNAP/$DATETAG
         fi
fi