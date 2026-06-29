# Troubleshooting

## 443 端口被占用

现象：

```text
failed to listen TCP on 443
```

检查：

```bash
ss -lntp | grep ':443'
systemctl status xray --no-pager
```

如果是旧 `xray.service` 占用：

```bash
systemctl disable --now xray
systemctl restart x-ui
ss -lntp | grep -E ':443|:2096'
```

## 订阅地址 404

先在服务器本地检查：

```bash
cat /root/current-subscription-url.txt
curl -I "$(cat /root/current-subscription-url.txt)"
```

如果返回 `404`，进入 3x-ui 面板，在 `Inbounds` 中找到客户端并复制面板生成的订阅链接。

## 本机无法更新订阅

在本机执行：

```powershell
curl.exe -v http://YOUR_SERVER_PUBLIC_IP:2096/sub/YOUR_SUB_ID
```

如果连接失败，通常是云防火墙或安全组没有开放 `TCP 2096`。

## 面板打不开

查看真实端口和路径：

```bash
grep -E 'XUI_ACCESS_URL|XUI_PANEL_PORT|XUI_WEB_BASE_PATH' /etc/x-ui/install-result.env
```

如果端口通但路径 404，复制 `XUI_ACCESS_URL` 的完整值打开。

## 回滚到旧手写 Xray

如果迁移不顺：

```bash
systemctl disable --now x-ui
systemctl enable --now xray
systemctl status xray --no-pager
```

旧配置备份在脚本输出的 `/root/xray-to-3x-ui-backup-时间戳/`。
