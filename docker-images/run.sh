#!/bin/sh

if [ "$NORUN" != "" ] ; then
    echo "NORUN set, sleeping forever"
    exec sleep infinity
fi

if [ ! -r /config/autostart ] ; then
    echo "No /config/autostart file found, sleeping forever"
    exec sleep infinity
fi



if [ ! -r /disks/simh/hostname ] ; then
    echo "No /disks/simh/hostname file, sleeping forever"
    exec sleep infinity
fi
hn=`cat /disks/simh/hostname`

grep "^$hn: autostart" /config/autostart
rc=$?

if [ $rc -ne 0 ] ; then
    echo "Not configured for autostart, sleeping forever"
    exec sleep infinity
fi

cd /disks/simh
/simh/BIN/vax8600

echo "simh exited, sleeping forever"
exec sleep infinity
