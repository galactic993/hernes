# syntax=docker/dockerfile:1.7

# ============================================================================
# hernes frontend (React + Vite) — multi-stage build for Cloud Run
# Build context は monorepo ルート（`docker build -f apps/frontend/Dockerfile .`）。
# 出力は静的アセットなので、最終段は nginx で 8080 配信する。
#
# 重要: ここでは VITE_* の build arg だけを受け取る。
#   CLERK_SECRET_KEY / DATABASE_URL 等の機密は絶対に build arg / ENV にしない。
#   VITE_* はクライアントに焼き込まれるため、publishable key 等の公開値のみ。
# ============================================================================

# ---------------------------------------------------------------------------
# Stage 1: deps — workspace の manifest だけを先にコピーして依存解決（キャッシュ最適化）
# ---------------------------------------------------------------------------
FROM node:22-alpine AS deps
WORKDIR /app

# corepack 経由で pnpm を有効化（バージョンは root package.json の packageManager に従う）
RUN corepack enable

# ルートの workspace 定義
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# frontend が依存する workspace パッケージの manifest（@hernes/shared）
COPY packages/shared/package.json packages/shared/package.json
# frontend 自身の manifest
COPY apps/frontend/package.json apps/frontend/package.json

# frontend とその依存 workspace のみインストール（lockfile 厳守）
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    corepack pnpm install --frozen-lockfile --filter @hernes/frontend...

# ---------------------------------------------------------------------------
# Stage 2: builder — ソースをコピーして Vite ビルド
# ---------------------------------------------------------------------------
FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable

# deps 段の node_modules（ルート + workspace 内）をそのまま再利用
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules
COPY --from=deps /app/apps/frontend/node_modules ./apps/frontend/node_modules

# workspace の manifest 群（pnpm がワークスペースを認識するため）
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# ソース（workspace 依存の @hernes/shared も含める）
COPY packages/shared packages/shared
COPY apps/frontend apps/frontend

# --- Vite build args（公開値のみ） ---
# VITE_* は import.meta.env としてバンドルに焼き込まれるので機密厳禁。
ARG VITE_APP_ENV
ARG VITE_API_BASE_URL
ARG VITE_CLERK_PUBLISHABLE_KEY
ENV VITE_APP_ENV=${VITE_APP_ENV}
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
ENV VITE_CLERK_PUBLISHABLE_KEY=${VITE_CLERK_PUBLISHABLE_KEY}

RUN corepack pnpm --filter @hernes/frontend build

# ---------------------------------------------------------------------------
# Stage 3: runtime — nginx で静的配信（Cloud Run は PORT=8080 を期待）
# ---------------------------------------------------------------------------
FROM nginx:1.27-alpine AS runtime

# デフォルト設定を置き換え（listen 8080 / SPA fallback / healthz）
RUN rm -f /etc/nginx/conf.d/default.conf
COPY apps/frontend/nginx.conf /etc/nginx/conf.d/default.conf

# ビルド成果物を配置
COPY --from=builder /app/apps/frontend/dist /usr/share/nginx/html

# Cloud Run / nginx:alpine は非 root（nginx user）でも 8080 を listen 可能
EXPOSE 8080

# nginx:alpine の default CMD（master をフォアグラウンド実行）をそのまま使用
CMD ["nginx", "-g", "daemon off;"]
