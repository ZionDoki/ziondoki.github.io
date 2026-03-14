# 远程部署说明

这个项目是 Astro 静态站点，推荐部署方式是：

1. 本地构建 `dist/`
2. 通过 `ssh + rsync` 上传到服务器
3. 服务器使用 `nginx` 直接托管静态文件
4. 用 `certbot` 自动签发 HTTPS 证书

## 适用环境

- 一台全新的 Ubuntu/Debian/Alibaba Cloud Linux/CentOS/RHEL 兼容服务器
- 本地可以通过 SSH 登录服务器
- 域名已经解析到服务器公网 IP

## 一键远程部署

先给脚本执行权限：

```bash
chmod +x ./scripts/deploy-remote.sh
```

再执行：

```bash
./scripts/deploy-remote.sh \
  --host 1.2.3.4 \
  --user root \
  --domain example.com \
  --www \
  --email ops@example.com
```

如果你暂时还没做好域名解析，先跳过 HTTPS：

```bash
./scripts/deploy-remote.sh \
  --host 1.2.3.4 \
  --user root \
  --domain example.com \
  --skip-ssl
```

如果你只是先按服务器 IP 临时访问，也可以把 `--domain` 先写成服务器 IP：

```bash
./scripts/deploy-remote.sh \
  --host 1.2.3.4 \
  --user root \
  --domain 1.2.3.4 \
  --skip-ssl
```

脚本会自动完成这些操作：

- 本地执行 `npm ci` 和 `npm run build`
- 以 `PUBLIC_SITE_URL` 构建站点
- 复用单个 SSH 会话，单次部署通常只需要输入一次服务器密码
- 远程安装 `nginx`、`rsync`、`certbot`
- 上传 `dist/` 到 `/var/www/<domain>`
- 写入 Nginx 站点配置
- 重载 Nginx
- 可选地签发并启用 Let's Encrypt HTTPS

## 常用参数

- `--host`：服务器公网 IP 或主机名
- `--user`：SSH 用户，默认 `root`
- `--port`：SSH 端口，默认 `22`
- `--domain`：主域名
- `--www`：同时配置 `www.<domain>`
- `--site-url`：构建站点时注入的 `PUBLIC_SITE_URL`
- `--remote-dir`：远程目录，默认 `/var/www/<domain>`
- `--email`：申请证书时使用的邮箱
- `--skip-ssl`：只部署 HTTP，不签发证书
- `--no-build`：跳过本地构建，直接上传已有 `dist/`

## 域名解析配置

假设服务器公网 IP 是 `1.2.3.4`：

### 根域名

- 记录类型：`A`
- 主机记录：`@`
- 记录值：`1.2.3.4`

### www 子域名

有两种常见方式，任选一种：

1. 再加一条 `A` 记录
   - 记录类型：`A`
   - 主机记录：`www`
   - 记录值：`1.2.3.4`
2. 或者用 `CNAME`
   - 记录类型：`CNAME`
   - 主机记录：`www`
   - 记录值：`example.com`

### IPv6

如果服务器还有公网 IPv6，可以额外加：

- 记录类型：`AAAA`
- 主机记录：`@` 或 `www`
- 记录值：你的 IPv6 地址

## 域名生效后检查

本地执行：

```bash
dig example.com +short
dig www.example.com +short
```

返回你的服务器公网 IP 后，再执行带 `--email` 的部署命令申请 HTTPS。

## 手动更新内容

以后更新站点通常只需要重新执行同一条部署命令。

## 注意事项

- 当前脚本会自动识别 `apt-get`、`dnf`、`yum`
- 服务器需要允许 `80` 和 `443` 入站
- 如果 SSH 用户不是 `root`，需要它具备无交互 `sudo` 能力；否则建议先使用 `root` 完成首装
