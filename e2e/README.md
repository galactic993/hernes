# e2e

クロスアプリ（React フロント ⇔ Hono バックエンド）の Playwright E2E を置く。
現状はスキャフォルドのみ（`pnpm test:e2e` は未配線）。

導入時:
```bash
pnpm add -D -w @playwright/test && pnpm exec playwright install
```
受け入れ条件のうち e2e 階層のもの（初期表示・画面遷移）をここで実装する。
