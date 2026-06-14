import { useAuth } from '@clerk/clerk-react'
import { apiFetch } from '../lib/api-client'

/**
 * Clerk セッショントークンを自動付与する API クライアントフック。
 * 例: const api = useApiClient(); await api.fetch('/api/me')
 */
export function useApiClient() {
  const { getToken } = useAuth()
  return {
    fetch: async (path: string, init?: RequestInit): Promise<Response> => {
      const token = await getToken()
      return apiFetch(path, token, init)
    },
  }
}
