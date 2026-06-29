# Security Checklist

上传公开仓库前，请确认这些内容没有被提交：

- 真实服务器 IP。
- 订阅 URL。
- 3x-ui 面板路径、用户名、密码、API token。
- Xray UUID、REALITY private key、shortId。
- `/etc/x-ui/x-ui.db` 数据库。
- 日志文件。
- 云服务器登录密码或 SSH 私钥。

服务器安全建议：

- `TCP 443` 可以开放给需要连接节点的客户端。
- `TCP 2096` 是订阅端口，建议只允许自己的公网 IP。
- 3x-ui 面板端口只临时开放，或只允许自己的公网 IP。
- root SSH 登录建议改为密钥登录，并限制 `TCP 22` 来源 IP。
- 定期更新系统软件包和 3x-ui。
- 不要在截图、Issue、README 中泄露订阅链接。

注意：每月轮换订阅 URL 只会让旧订阅地址失效，不会让已经导入客户端的旧节点配置立即失效。如需让旧节点配置也失效，需要同时轮换客户端 UUID。
