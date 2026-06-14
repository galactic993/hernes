/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_ENV?: 'preview' | 'staging' | 'production' | string
  readonly VITE_API_BASE_URL?: string
  // 公開可能キーのみ。CLERK_SECRET_KEY 等の機密は VITE_* に絶対入れない。
  readonly VITE_CLERK_PUBLISHABLE_KEY?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
