# Beside Lake Baikal

基于 [Hexo](https://hexo.io/) 的静态博客，使用 [NexT](https://theme-next.js.org/) 主题，通过 GitHub Actions 自动部署到 GitHub Pages。

- **站点地址**：<https://cartery2022.github.io/>

## 技术栈

| 项目 | 说明 |
|------|------|
| 框架 | Hexo 8 |
| 主题 | NexT |
| 托管 | GitHub Pages（发布分支 `gh-pages`） |
| CI/CD | GitHub Actions（推送到 `main` 时自动构建并部署） |

## 环境要求

- Node.js：见 [.nvmrc](.nvmrc)，建议使用 `nvm use` 切换版本
- npm：随 Node 安装即可

## 本地开发

```bash
# 安装依赖
npm install

# 本地预览（默认 http://localhost:4000）
npm run server

# 仅构建静态文件
npm run build

# 清理缓存后重新构建
npm run clean && npm run build
```

## 部署方式

推送代码到 `main` 分支后，GitHub Actions 会：

1. 使用 `.nvmrc` 指定版本安装 Node
2. 执行 `npm ci` 安装依赖
3. 执行 `npm run build`（即 `hexo generate`）生成站点
4. 将 `public/` 推送到 `gh-pages` 分支

仓库需在 **Settings → Pages** 中设置：Source 为 **Deploy from a branch**，分支选 **gh-pages**，目录为 **/ (root)**。

## 项目结构（简要）

```
├── _config.yml          # 站点配置
├── _config.next.yml     # NexT 主题配置
├── .nvmrc               # Node 版本（供本地与 CI 使用）
├── .github/workflows/   # GitHub Actions 工作流
├── source/
│   ├── _posts/          # 博文（Markdown）
│   ├── _data/           # 主题覆盖、自定义样式等
│   ├── categories/      # 分类页
│   └── tags/            # 标签页
├── themes/              # 主题目录（NexT 通过 npm 安装）
└── public/              # 构建输出（不提交，由 CI 推到 gh-pages）
```

## 写新文章

在 `source/_posts/` 下新建 Markdown 文件，使用 Hexo 约定的 front matter（如 `title`、`date`、`tags`、`categories`）。可复制已有文章或使用：

```bash
hexo new "文章标题"
```

## 许可证

私有博客项目，未单独声明许可证。
