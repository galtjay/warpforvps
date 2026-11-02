FROM ubuntu:24.04
LABEL maintainer="galtjay<galtjay1991@gmail.com>"

ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖 + Cloudflare WARP 官方仓库（参考 https://pkg.cloudflareclient.com/）
# 注意：公钥在 2025-09-12 之后有更新，这里每次构建都重新拉取最新公钥；
# 仓库代号使用 lsb_release -cs（Ubuntu 24.04 => noble），不再硬编码 jammy。
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      lsb-release \
      procps \
      supervisor \
 && mkdir -p /usr/share/keyrings \
 && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
 && chmod 644 /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/cloudflare-client.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends cloudflare-warp \
 && rm -rf /var/lib/apt/lists/*

# warp-svc 原本由 systemd 管理，容器内改用 supervisor 守护。
COPY warp-supervisor.conf /etc/supervisor/conf.d/warp.conf

# 容器启动脚本：注册 -> 设为 proxy 模式 -> 连接 -> 校验 warp=on
COPY init.sh /init.sh
RUN chmod +x /init.sh

# WARP proxy 模式默认监听 40000 端口，暴露给宿主机使用。
# 用法：curl --proxy socks5://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace
EXPOSE 40000

ENTRYPOINT ["/init.sh"]
