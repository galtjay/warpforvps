#!/bin/bash
ip=$myip
while true
ipnow=`export ALL_PROXY=socks5://127.0.0.1:40000 && curl myip.ipip.net | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'`
echo "current ip is "$ipnow "expect ip is" $ip >> /var/log/warp.log
do
  if [ -z "$ip" ]; then
    echo "IP address is not set" >> /var/log/warp.log
    break
  elif [[ "$ipnow" ==  "$ip" ]]; then
    echo "IP address meets the expected state,sleep 10 mins" >> /var/log/warp.log
    sleep 600
  else
    echo "Start to change ip address" >> /var/log/warp.log
    warp-cli --accept-tos disconnect
    sleep 10
    warp-cli --accept-tos connect
    sleep 10
  fi
done
