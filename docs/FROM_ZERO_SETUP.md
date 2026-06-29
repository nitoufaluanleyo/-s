# From Zero Setup Guide

这份文档从购买服务器开始，整理一套完整流程。所有示例里的 `YOUR_SERVER_PUBLIC_IP` 都要替换成你自己的服务器公网 IP。

## 1. 购买服务器

推荐配置：

- 系统：Ubuntu 22.04 LTS 或 Ubuntu 24.04 LTS。
- 内存：至少 1 GB，推荐 2 GB。
- CPU：1 核可用，2 核更稳。
- 带宽：按自己的使用量选择。
- 位置：选择离自己网络更近、延迟更低的地区。

购买后记录：

- 公网 IP。
- root 密码或 SSH 私钥。
- 云厂商控制台的防火墙/安全组入口。

## 2. 配置防火墙

先开放这些端口：

| 端口 | 协议 | 用途 | 来源建议 |
| --- | --- | --- | --- |
| `22` | TCP | SSH 登录 | 只允许自己的公网 IP |
| `443` | TCP | VLESS REALITY 节点 | 允许需要连接的客户端 |
| `2096` | TCP | 订阅地址 | 尽量只允许自己的公网 IP |

安装 3x-ui 后还会生成一个随机面板端口。这个端口只临时开放，或者只允许自己的公网 IP。

## 3. 登录服务器

Windows PowerShell 示例：

```powershell
ssh root@YOUR_SERVER_PUBLIC_IP
```

进入服务器后切换 root：

```bash
sudo -i
```

更新基础组件：

```bash
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
apt-get update
apt-get install -y curl ca-certificates openssl python3
```

## 4. 安装 3x-ui

3x-ui 官方安装命令：

```bash
XUI_NONINTERACTIVE=1 XUI_SSL_MODE=none bash <(curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

安装完成后查看面板信息：

```bash
cat /etc/x-ui/install-result.env
```

里面会包含：

- 面板端口。
- 面板随机路径。
- 用户名。
- 密码。
- API token。

不要把这个文件内容公开。

## 5. 打开面板

在浏览器中打开 `XUI_ACCESS_URL` 的完整地址。

如果浏览器打不开，通常是云防火墙没有放行面板端口。只给自己的公网 IP 临时开放即可。

## 6. 创建 VLESS REALITY 入站

在 3x-ui 面板中进入 `Inbounds`，新增入站：

- Protocol：`VLESS`
- Listen IP：`0.0.0.0`
- Port：`443`
- Transmission：`TCP` 或 `raw`
- Security：`REALITY`
- Flow：留空
- uTLS / Fingerprint：`chrome`
- SNI / Server Names：选择一个真实可访问的 HTTPS 域名
- Dest：通常为 `SNI:443`
- SpiderX：`/`

保存后重启入站或重启 `x-ui`：

```bash
systemctl restart x-ui
ss -lntp | grep ':443'
```

如果 `443` 监听正常，说明节点端口已经起来。

## 7. 创建客户端并限制 100GB

在入站的客户端列表中新增或编辑客户端：

- Email：`main-100g`
- Enable：开启
- Total Traffic：`100GB`
- Expiry：不设置固定过期时间
- Subscription：开启

保存后复制该客户端的订阅链接。

默认订阅格式通常类似：

```text
http://YOUR_SERVER_PUBLIC_IP:2096/sub/YOUR_SUB_ID
```

实际地址以面板复制出来的为准。

## 8. 客户端导入

v2rayN 示例：

1. 打开 `订阅分组设置`。
2. 添加一个订阅分组。
3. URL 填入面板复制出的订阅链接。
4. 保存。
5. 更新订阅。
6. 选择拉取到的节点连接。

Windows 测试：

```powershell
curl.exe -v --proxy socks5h://127.0.0.1:10808 https://ipinfo.io
```

如果返回的 IP 是服务器公网 IP，说明客户端连接成功。

## 9. 配置每月订阅 URL 轮换

如果你使用本仓库的迁移脚本，脚本会自动安装：

- `/root/rotate-3x-ui-subscription.py`
- `rotate-3x-ui-subscription.service`
- `rotate-3x-ui-subscription.timer`

检查 timer：

```bash
systemctl status rotate-3x-ui-subscription.timer --no-pager
```

手动轮换一次：

```bash
python3 /root/rotate-3x-ui-subscription.py
cat /root/current-subscription-url.txt
```

如果你是完全手动搭建，没有使用迁移脚本，可以参考 `scripts/migrate-to-3x-ui-subscription.sh` 里的 `write_rotation_script` 部分，或在面板中手动：

1. 重置客户端流量。
2. 重新生成订阅 ID。
3. 复制新的订阅 URL。
4. 在客户端中更新订阅地址。

## 10. 日常维护

检查服务状态：

```bash
systemctl status x-ui --no-pager
ss -lntp | grep -E ':443|:2096'
```

查看当前订阅 URL：

```bash
cat /root/current-subscription-url.txt
```

更新系统：

```bash
apt-get update
apt-get upgrade -y
```

面板端口使用完后建议关闭公网访问，或只允许自己的公网 IP。

## 11. 常见问题

- 订阅更新失败：检查 `TCP 2096` 是否开放。
- 面板打不开：检查面板端口和 `XUI_ACCESS_URL`。
- 节点连不上：检查 `TCP 443` 是否开放，`x-ui` 是否运行。
- 订阅地址返回 `404`：到面板中复制真实订阅链接。
- `443` 被占用：停掉旧的 `xray.service` 或其他占用 443 的服务。

更多排查见：[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)。
