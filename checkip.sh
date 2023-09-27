#!/bin/bash
IFS=',' read -r -a ips_array <<< "$myip"
sleep 5
while true
ipnow=`export ALL_PROXY=socks5://127.0.0.1:40000 && curl https://chat.openai.com/cdn-cgi/trace | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'`
echo "current ip is "$ipnow "excluded ip is" $myip >> /var/log/warp.log
do

  if [ -z "$myip" ]; then
    echo "IP address is not set" >> /var/log/warp.log
    break
  else	
	  found=false
	  for ip in "${ips_array[@]}"; do
	  if [[ "$ip" == "$ipnow" ]]; then
		found=true
		break
	  fi
		done
	if [[ $found  == false ]]; then
    echo "IP address meets the expected state,sleep 10 mins" >> /var/log/warp.log
    sleep 600
  else
    echo "Start to change ip address" >> /var/log/warp.log
    warp-cli --accept-tos disconnect
    sleep 3
    warp-cli --accept-tos connect
    sleep 1

  fi
  fi
done
