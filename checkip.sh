#!/bin/bash
ip=$myip #在docker运行时需要进行传递，不传递的话默认会终止程序
while true
ipnow=`export ALL_PROXY=socks5://127.0.0.1:40000 &&curl ifconfig.me`
echo "current ip is "$ipnow "expect ip is" $ip >> /var/log/warp.log
do
  if [ -z "$ip" ]; then
    echo "IP address is not set" >> /var/log/warp.log
    break
  elif [ $ipnow == $ip ]; then
    echo "IP address meets the expected state,sleep 10 mins" >> /var/log/warp.log
    sleep 600
  else
    echo "Start to change ip address" >> /var/log/warp.log
    warp-cli disconnect && sleep 3 &&warp-cli connect && sleep 10
  fi
done

