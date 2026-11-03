# warpforvps

> 成品镜像 / Prebuilt image: `galtjay/warp:20261102`
> ```bash
> docker pull galtjay/warp:20261102
> ```

在 Docker 中运行 Cloudflare WARP 客户端，暴露 SOCKS5 代理端口 `40000` 给宿主机使用。
Run the Cloudflare WARP client in Docker and expose the SOCKS5 proxy port `40000` to the host.

启动容器后自动完成：注册客户端（`warp-cli registration new`）→ 切换 proxy 模式 → 连接（`warp-cli connect`）→ 校验 `warp=on`。
On startup the container automatically: registers the client (`warp-cli registration new`) → switches to proxy mode → connects (`warp-cli connect`) → verifies `warp=on`.

## 参考文档 / References

- WARP 包源 / WARP package repository: https://pkg.cloudflareclient.com/
- Linux 客户端 / Linux client: https://developers.cloudflare.com/warp-client/get-started/linux/

## build / 构建

本地自行构建，镜像名为 `warp:20261102`，构建完成后把下文中出现 `galtjay/warp:20261102` 的地方替换成 `warp:20261102` 即可。
To build locally as `warp:20261102`; afterwards replace `galtjay/warp:20261102` with `warp:20261102` in the commands below.

```bash
docker build -t warp:20261102 ./
```

## run / 运行

推荐使用 host 网络（代理只监听 127.0.0.1）。
Host networking is recommended, because WARP's proxy only listens on 127.0.0.1.

```bash
docker run -d --name warp --network host --cap-add NET_ADMIN galtjay/warp:20261102
```

如果使用桥接网络，必须让 WARP 监听宿主机可达的地址（否则 40000 端口只绑定在容器的 127.0.0.1 上）。
If you use bridge networking, WARP must listen on an address reachable from the host, otherwise port 40000 is only bound to the container's 127.0.0.1.

```bash
docker run -d --name warp -p 40000:40000 -e WARP_PROXY_HOST=0.0.0.0 --cap-add NET_ADMIN galtjay/warp:20261102
```

## compose

```yaml
services:
  warp:
    image: galtjay/warp:20261102
    container_name: warp
    network_mode: host
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
```

## 查看日志 / 状态 · Logs & status

```bash
docker logs -f warp
docker exec -it warp warp-cli --accept-tos status
```

## how to test / 测试

```bash
# 校验 warp=on / verify that warp=on
curl --proxy socks5h://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace

# 也可以当 HTTP 代理用（warp 的 proxy 模式支持 HTTP CONNECT）
# Can also be used as an HTTP proxy (WARP proxy mode supports HTTP CONNECT)
curl --proxy http://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace
```
