# Blog

## 本地开发

```bash
npm install
npm run dev
```

## 构建

```bash
npm run build
```

如果要生成正确的线上站点地址，可以在构建前设置：

```bash
PUBLIC_SITE_URL=https://example.com npm run build
```

也可以参考 [`.env.example`](/mnt/c/Workspace/blog/.env.example)。

## 一键远程部署

仓库已包含面向空白 Ubuntu/Debian 服务器的远程部署脚本：

```bash
chmod +x ./scripts/deploy-remote.sh
./scripts/deploy-remote.sh \
  --host 1.2.3.4 \
  --user root \
  --domain example.com \
  --www \
  --email ops@example.com
```

完整说明见 [`docs/deploy.md`](/mnt/c/Workspace/blog/docs/deploy.md)。

## GitHub Pages

项目已包含 GitHub Pages 工作流和自定义域名配置：

- 工作流： [`.github/workflows/deploy.yml`](/mnt/c/Workspace/blog/.github/workflows/deploy.yml)
- 自定义域名： [`public/CNAME`](/mnt/c/Workspace/blog/public/CNAME)

如果你要部署到 GitHub Pages，只需要：

1. 新建 GitHub 仓库并推送到 `main`
2. 在仓库 `Settings -> Pages` 中把 `Source` 设为 `GitHub Actions`
3. 在 `Settings -> Pages` 中确认自定义域名为 `ziang.site`
4. 把 DNS 解析改到 GitHub Pages

`ziang.site` 根域名需要配置 GitHub Pages 官方 A 记录：

- `185.199.108.153`
- `185.199.109.153`
- `185.199.110.153`
- `185.199.111.153`

`www` 建议配置：

- `CNAME` -> `<你的 GitHub 用户名>.github.io`
