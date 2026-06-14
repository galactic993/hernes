# syntax=docker/dockerfile:1.7

# ============================================================================
# hernes backend (Hono + TypeScript) — multi-stage build for Cloud Run
# 重要: backend は Java ではない。tsx で TypeScript を直接実行する（ビルド/トランスパイル無し）。
# Build context は monorepo ルート（`docker build -f apps/backend/Dockerfile .`）。
#
# workspace 依存 (@hernes/shared, @hernes/db) はソース(.ts)のみのパッケージで、
# tsx が直接読み込む。そのため `pnpm deploy` で workspace を実体化し、
# 自己完結した node_modules を持つ deploy ディレクトリを runtime に渡す。
# ============================================================================

# ---------------------------------------------------------------------------
# Stage 1: deps — workspace 全体を frozen install（deploy のために workspace が必要）
# ---------------------------------------------------------------------------
FROM node:22-alpine AS deps
WORKDIR /app
RUN corepack enable

# ルートの workspace 定義
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# backend が依存する workspace パッケージの manifest
COPY packages/shared/package.json packages/shared/package.json
COPY packages/db/package.json packages/db/package.json
COPY apps/backend/package.json apps/backend/package.json

# backend とその依存 workspace のみインストール（lockfile 厳守）
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    corepack pnpm install --frozen-lockfile --filter @hernes/backend...

# ---------------------------------------------------------------------------
# Stage 2: builder — ソースを入れ、pnpm deploy で自己完結ディレクトリを生成
# ---------------------------------------------------------------------------
FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable

# deps 段の依存をそのまま再利用
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules
COPY --from=deps /app/packages/db/node_modules ./packages/db/node_modules
COPY --from=deps /app/apps/backend/node_modules ./apps/backend/node_modules

# workspace manifest 群
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# ソース（backend 本体と workspace 依存の実体）
COPY packages/shared packages/shared
COPY packages/db packages/db
COPY apps/backend apps/backend

# pnpm deploy: @hernes/backend を /app/deploy へ実体化。
#   --prod で devDependencies を除外（ただし tsx は本番実行に必要なので下記補足参照）。
#   --legacy は workspace 外への deploy を許可するため（pnpm 10 では injected 等の都合で使用）。
# tsx は backend の devDependency だが「本番実行に必須」のため、--prod では落ちる。
#   → deploy 後に tsx を明示的に prod 依存として追加インストールする。
RUN corepack pnpm --filter @hernes/backend deploy --prod --legacy /app/deploy

# tsx を deploy ディレクトリ内に本番インストール（root package.json の指定版に合わせる）
WORKDIR /app/deploy
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    corepack pnpm add tsx@4.19.2

# ---------------------------------------------------------------------------
# Stage 3: runtime — node:22-alpine で tsx 実行（非 root）
# ---------------------------------------------------------------------------
FROM node:22-alpine AS runtime
WORKDIR /app

# 環境
ENV NODE_ENV=production
ENV PORT=8080

# tini を PID1 にして SIGTERM を子プロセスへ確実に伝播させる
#   Cloud Run はスケールダウン時に SIGTERM を送る。アプリ側 (@hono/node-server) が
#   graceful shutdown を実装している前提で、シグナルが届く構成にしておく。
RUN apk add --no-cache tini

# corepack（pnpm 経由で start したい場合のため。tsx 直叩きなら不要だが互換のため有効化）
RUN corepack enable

# 非 root 実行（node:alpine 標準の node ユーザを使用）
# deploy 成果物を node 所有でコピー
COPY --from=builder --chown=node:node /app/deploy ./

USER node

EXPOSE 8080

# ヘルスチェック: GET /healthz を叩く（Node 内蔵 http を使用、追加依存なし）
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# tini 経由で tsx を起動（`pnpm --filter @hernes/backend start` 相当 = tsx src/index.ts）。
# deploy 後はパッケージルート直下に src/ が来るため src/index.ts を直接指定する。
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node_modules/.bin/tsx", "src/index.ts"]
