import { ClerkProvider } from '@clerk/clerk-react'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'

// 公開可能キー。build 時に VITE_CLERK_PUBLISHABLE_KEY として注入する。
const publishableKey = import.meta.env.VITE_CLERK_PUBLISHABLE_KEY
if (!publishableKey) {
  throw new Error('VITE_CLERK_PUBLISHABLE_KEY is not set (Clerk publishable key required)')
}

const el = document.getElementById('root')
if (el) {
  createRoot(el).render(
    <StrictMode>
      <ClerkProvider publishableKey={publishableKey}>
        <App />
      </ClerkProvider>
    </StrictMode>,
  )
}
