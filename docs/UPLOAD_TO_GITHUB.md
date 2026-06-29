# Upload To GitHub

这个目录已经去掉真实服务器信息，可以作为一个新仓库上传。

## 初始化仓库

```bash
cd github-ready-vless-3xui
git init
git add .
git commit -m "Initial 3x-ui VLESS REALITY subscription toolkit"
```

## 关联 GitHub 仓库

先在 GitHub 创建空仓库，然后执行：

```bash
git branch -M main
git remote add origin https://github.com/YOUR_NAME/YOUR_REPO.git
git push -u origin main
```

## 上传前再检查一次

```bash
git grep -n "YOUR_REAL_IP_OR_SUB_ID"
git grep -n "password"
git grep -n "sub/"
git status
```

如果命令找到了真实 IP、订阅链接、密码、token，不要上传，先删除或替换成占位符。
