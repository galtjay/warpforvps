FROM ubuntu:22.10
LABEL mantainer="galtjay<galtjay@foxmail.com>"
#下边这一行主要是完成supervisor和cloudflare-warp的安装
RUN apt update && apt install -y curl gpg supervisor && curl https://pkg.cloudflareclient.com/pubkey.gpg |  gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" |  tee /etc/apt/sources.list.d/cloudflare-client.list && apt update && apt install cloudflare-warp -y &&  apt-get clean
#生成supervisor守护配置文件，原本的warp-svc基于systemd进行管理，docker内部不太好实现，切换成supervisor进行守护。
RUN echo "[program:warp-svc]\ncommand=/bin/bash -c /usr/bin/warp-svc\nautostart=true\nautorestart=true\nstartretries=3\nstderr_logfile=/var/log/warp.log\nstdout_logfile=/var/log/warp.log\n" > /etc/supervisor/conf.d/warp.conf
#生成docker启动脚本，输出日志到控制台。每次启动会自动的完成注册，切换模式。假如各位需要嵌入现有的license，此处自行修改。主要修改warp-cli --accept-tos register这条。
COPY init.sh /init.sh
COPY checkip.sh /checkip.sh 
RUN chmod +x /init.sh && chmod +x /checkip.sh
#默认暴露40000端口
EXPOSE "40000/tcp"
CMD ["bash","-c","/init.sh"]
