# VLESS REALITY + 3x-ui Subscription Guide

这个仓库整理了一套从零搭建到后期维护的流程，用 3x-ui 管理 `VLESS + REALITY + TCP/raw + 443` 节点、订阅地址、客户端流量限制和每月订阅 URL 轮换。

本仓库不包含任何真实服务器 IP、面板路径、订阅 URL、UUID、私钥或密码。上传 GitHub 前请不要提交你服务器上的 `/etc/x-ui/install-result.env`、`/root/current-subscription-url.txt`、数据库或日志。

请遵守服务器所在地法律法规、云厂商服务条款和上游项目许可证。

## 适合谁

- 想在自己的 Ubuntu VPS 上部署 VLESS REALITY。
- 想用 3x-ui 面板管理节点和订阅。
- 想给客户端设置总流量限制，例如每月 `100GB`。
- 想每月重置流量并更换订阅 URL。

## 文档路线

从零开始搭建：

1. 购买 Ubuntu VPS。
2. 配置云防火墙/安全组。
3. 安装 3x-ui。
4. 创建 `VLESS + REALITY + TCP/raw + 443` 入站。
5. 创建客户端并设置流量限制。
6. 导入订阅到客户端。
7. 配置每月重置和订阅 URL 轮换。

完整步骤见：[docs/FROM_ZERO_SETUP.md](./docs/FROM_ZERO_SETUP.md)

已有手写 Xray 节点，想迁移到 3x-ui：

```bash
sudo -i
cd /root
SERVER_IP="YOUR_SERVER_PUBLIC_IP" bash ./migrate-to-3x-ui-subscription.sh
```

脚本见：[scripts/migrate-to-3x-ui-subscription.sh](./scripts/migrate-to-3x-ui-subscription.sh)

## 仓库内容

- `scripts/migrate-to-3x-ui-subscription.sh`：从现有手写 Xray 配置迁移到 3x-ui。
- `docs/FROM_ZERO_SETUP.md`：从买服务器开始的完整搭建步骤。
- `docs/SECURITY.md`：安全检查清单。
- `docs/TROUBLESHOOTING.md`：常见问题排查。
- `docs/UPLOAD_TO_GITHUB.md`：上传 GitHub 的步骤。
- `NOTICE.md`：上游开源项目来源、作者/维护者和许可证说明。

## 端口规划

| 端口 | 用途 | 建议 |
| --- | --- | --- |
| `22` | SSH 登录 | 只允许自己的公网 IP |
| `443` | VLESS REALITY 节点 | 允许需要连接的客户端访问 |
| `2096` | 3x-ui 默认订阅服务 | 尽量只允许自己的公网 IP |
| 随机面板端口 | 3x-ui 后台 | 只临时开放，或只允许自己的公网 IP |

## 迁移脚本参数

如果你已经有一条可用的手写 Xray `VLESS + REALITY` 配置，可以用脚本迁移：

```bash
SERVER_IP="YOUR_SERVER_PUBLIC_IP" \
CLIENT_EMAIL="main-100g" \
LIMIT_GB="100" \
bash ./migrate-to-3x-ui-subscription.sh
```

脚本会尝试：

- 备份现有 `/usr/local/etc/xray/config.json`。
- 安装 3x-ui。
- 生成 3x-ui 入站导入 JSON。
- 停止旧 `xray.service`，避免 `443` 端口冲突。
- 导入 `VLESS + REALITY` 入站。
- 创建每月订阅 URL 轮换 timer。

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
- 上传 GitHub 前先看 `.gitignore` 和 [docs/SECURITY.md](./docs/SECURITY.md)。

## 开源来源与作者

本仓库是部署脚本和操作手册，不包含 3x-ui、Xray-core 或 v2rayN 源码。使用到的开源项目和作者/维护者见 [NOTICE.md](./NOTICE.md)。
