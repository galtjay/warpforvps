#!/bin/bash
supervisord
sleep 5
warp-cli --accept-tos registration new
warp-cli --accept-tos  mode proxy
warp-cli  --accept-tos connect
tail -f /var/log/warp.log


