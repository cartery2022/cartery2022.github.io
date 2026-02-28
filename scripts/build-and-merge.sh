#!/usr/bin/env bash
# 根目录同一份环境：中文在根目录 /，英文在 /en/
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EN_DIR="$ROOT/cartery.github.io.en"
PUBLIC="$ROOT/public"

echo "[build] Root: $ROOT"

# 0. 根目录一份依赖，en 子目录用符号链接共用
if [[ ! -d "$ROOT/node_modules" ]]; then
  echo "[build] Installing dependencies (once at root)..."
  cd "$ROOT" && npm install
fi
if [[ -d "$EN_DIR/node_modules" ]] && [[ ! -L "$EN_DIR/node_modules" ]]; then
  rm -rf "$EN_DIR/node_modules"
fi
if [[ ! -e "$EN_DIR/node_modules" ]]; then
  echo "[build] Link node_modules -> cartery.github.io.en"
  ln -sf "../node_modules" "$EN_DIR/node_modules"
fi

# 1. 根目录构建中文站（输出到 public/ 根路径）
echo "[build] Generating main site (zh-CN at /)..."
cd "$ROOT" && npx hexo generate --silent && cd "$ROOT"

# 2. 构建 en，合并到 public/en/
echo "[build] Generating en..."
cd "$EN_DIR" && npx hexo generate --silent && cd "$ROOT"
if [[ -d "$EN_DIR/public/en" ]]; then
  cp -R "$EN_DIR/public/en" "$PUBLIC/"
else
  mkdir -p "$PUBLIC/en"
  cp -R "$EN_DIR/public/." "$PUBLIC/en/"
fi

# 3. 为 /en/ 注入 <base href="/en/">，保证样式与链接一致
echo "[build] Injecting <base> for /en/..."
if [[ -d "$PUBLIC/en" ]]; then
  find "$PUBLIC/en" -name '*.html' -type f -exec perl -i -0pe 's|<head([^>]*)>|<head$1>\n<base href="/en/">|' {} \;
fi

echo "[build] Done. Output: $PUBLIC"
echo "  - /         (中文)"
echo "  - /en/      (EN)"
echo ""
echo "Run locally:  npm run serve   # then open http://localhost:4000 and http://localhost:4000/en/"
