#!/bin/bash
supervisord
sleep 5
warp-cli --accept-tos register
warp-cli --accept-tos  set-mode proxy
warp-cli  --accept-tos connect
nohup sh ./checkip.sh  &
tail -f /var/log/warp.log

