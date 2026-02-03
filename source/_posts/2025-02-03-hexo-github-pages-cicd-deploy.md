---
title: Hexo 博客用 GitHub Actions 部署到 GitHub Pages
date: 2025-02-03
tags:
  - hexo
  - github-actions
  - github-pages
  - cicd
categories:
  - 运维
  - 博客
---

# Hexo 博客用 GitHub Actions 部署到 GitHub Pages

本博客通过 GitHub Actions 自动构建 Hexo 并部署到 GitHub Pages，访问地址：

**https://cartery.github.io**

## 技术栈

- **框架**：Hexo 8 + NexT 主题
- **托管**：GitHub Pages（发布分支 `gh-pages`）
- **CI/CD**：GitHub Actions（push 到 `main` 时自动构建并部署）

## 要点摘要

| 项目 | 说明 |
|------|------|
| Node 版本 | 用 `.nvmrc` + `package.json` 的 `engines` 固定为 24.12.0，本地与 CI 一致 |
| 依赖 | 插件写在 `package.json`，用 `package-lock.json` 锁定版本；CI 里用 `npm ci` 复现同一套依赖 |
| 主题 | NexT 通过 npm 安装；CI 中把 `node_modules/hexo-theme-next` 复制到 `themes/next`，保证 Hexo 能正确加载主题 |
| 站点 URL | `_config.yml` 中 `url: https://cartery.github.io`，用于生成正确链接 |

## 相关文件

- 工作流：`.github/workflows/deploy.yml`
- 站点配置：`_config.yml`、`_config.next.yml`
- 版本与依赖：`.nvmrc`、`package.json`、`package-lock.json`

推送代码到 `main` 后，Actions 会自动执行构建并更新站点。
