import { customerSearchSchema } from '@hernes/shared'
import { useState } from 'react'

/**
 * 得意先選択モーダル（FR-004: 得意先コード/名で検索し選択）。
 * 得意先コードのバリデーションは @hernes/shared（半角数字・5桁以内）を再利用する。
 */
export interface Customer {
  code: string
  name: string
}

export function CustomerSelectModal({
  open,
  customers,
  onSelect,
  onClose,
}: {
  open: boolean
  customers: Customer[]
  onSelect: (customer: Customer) => void
  onClose: () => void
}) {
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)

  if (!open) return null

  const onSearch = () => {
    const r = customerSearchSchema.safeParse({ customerCode: code || undefined })
    if (!r.success) {
      setError(r.error.issues[0]?.message ?? '')
      return
    }
    setError(null)
  }

  const filtered = code === '' ? customers : customers.filter((c) => c.code.includes(code))

  return (
    <dialog open aria-label="得意先選択">
      <label>
        得意先コード
        <input value={code} onChange={(e) => setCode(e.target.value)} maxLength={10} />
      </label>
      <button type="button" onClick={onSearch}>
        検索
      </button>
      {error ? (
        <span role="alert">{error}</span>
      ) : (
        <ul>
          {filtered.map((c) => (
            <li key={c.code}>
              <button type="button" onClick={() => onSelect(c)}>
                {c.code} {c.name}
              </button>
            </li>
          ))}
        </ul>
      )}
      <button type="button" onClick={onClose}>
        閉じる
      </button>
    </dialog>
  )
}
