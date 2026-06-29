# 3x-ui VLESS REALITY Subscription Toolkit

这个仓库整理了一套在 Ubuntu 服务器上迁移到 `3x-ui` 的流程，用于管理 `VLESS + REALITY + TCP/raw + 443` 节点、订阅地址、客户端流量限制和每月订阅 URL 轮换。

本仓库不包含任何真实服务器 IP、面板路径、订阅 URL、UUID、私钥或密码。上传 GitHub 前请不要提交你服务器上的 `/etc/x-ui/install-result.env`、`/root/current-subscription-url.txt`、数据库或日志。

## 功能

- 备份现有手写 Xray 配置。
- 安装 3x-ui。
- 尝试从现有 Xray `VLESS + REALITY` 配置生成 3x-ui 入站导入文件。
- 创建 `main-100g` 客户端，默认每月 `100GB`。
- 配置订阅服务。
- 创建 systemd timer，每月重置流量并轮换订阅 URL。

## 前提

- Ubuntu 22.04/24.04。
- root 权限。
- 已经有一条可用的手写 Xray `VLESS + REALITY` 配置，默认位置为 `/usr/local/etc/xray/config.json`。
- 服务器安全组/防火墙允许：
  - `TCP 443`：节点端口。
  - `TCP 2096`：3x-ui 默认订阅端口，建议只允许自己的 IP。
  - 3x-ui 面板随机端口：只临时开放或只允许自己的 IP。

## 快速使用

上传脚本到服务器后执行：

```bash
sudo -i
cd /root
SERVER_IP="YOUR_SERVER_PUBLIC_IP" bash ./migrate-to-3x-ui-subscription.sh
```

可选参数：

```bash
SERVER_IP="YOUR_SERVER_PUBLIC_IP" \
CLIENT_EMAIL="main-100g" \
LIMIT_GB="100" \
bash ./migrate-to-3x-ui-subscription.sh
```

脚本结束后查看：

```bash
cat /etc/x-ui/install-result.env
cat /root/current-subscription-url.txt
systemctl status x-ui --no-pager
systemctl status rotate-3x-ui-subscription.timer --no-pager
```

## 客户端导入

在 v2rayN、v2rayNG、NekoBox、Shadowrocket 或 sing-box 类客户端中添加订阅，填入：

```text
http://YOUR_SERVER_PUBLIC_IP:2096/sub/YOUR_SUB_ID
```

实际地址以服务器 `/root/current-subscription-url.txt` 或 3x-ui 面板复制出的订阅链接为准。

## 每月轮换

脚本会安装：

- `/root/rotate-3x-ui-subscription.py`
- `rotate-3x-ui-subscription.service`
- `rotate-3x-ui-subscription.timer`

手动轮换一次：

```bash
python3 /root/rotate-3x-ui-subscription.py
cat /root/current-subscription-url.txt
```

说明：轮换订阅 URL 会使旧订阅地址失效，但已经导入客户端的旧节点配置不一定立刻失效。旧节点仍受同一个客户端流量限制。如果要让旧节点配置也失效，需要同时轮换 UUID。

## 安全建议

- 面板端口不要对全网开放。
- 订阅端口 `2096` 尽量限制来源 IP。
- 不要公开订阅 URL、面板路径、面板账号密码、UUID、REALITY private key。
- 定期更新系统和 3x-ui。
- 上传 GitHub 前先看 `.gitignore` 和 `SECURITY.md`。

## 开源来源与作者

本仓库是部署脚本和操作手册，不包含 3x-ui、Xray-core 或 v2rayN 源码。使用到的开源项目和作者/维护者见 [NOTICE.md](./NOTICE.md)。

请遵守服务器所在地法律法规、云厂商服务条款和上游项目许可证。
