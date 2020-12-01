#!/bin/sh

. /etc/rc.subr
load_rc_config

if [ "$UPLOAD_VUSER" = "ftp" ] ; then
    UPLOAD_VUSER="Anonymous"
fi

echo "`date`: $UPLOAD_VUSER has uploaded file $1 with size $UPLOAD_SIZE" >> /var/log/uploadscript.log
