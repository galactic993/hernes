import { PROD_QUOTE_STATUS, PROD_QUOTE_STATUS_CODES } from '@hernes/shared'
import { useState } from 'react'
import { validateProdQuoteSearch } from './validate'

/**
 * 制作見積情報検索フォーム（画面設計書「項目記述書」No.1,2,3,5,6）。
 * 送信前にクライアント側バリデーション（共有スキーマ）を実行する。
 */
export function SearchForm() {
  const [status, setStatus] = useState<string>('00')
  const [quotNo, setQuotNo] = useState('')
  const [errors, setErrors] = useState<Record<string, string[] | undefined>>({})

  const onSearch = () => {
    const result = validateProdQuoteSearch({ status, quotNo: quotNo || undefined })
    if (!result.ok) {
      setErrors(result.errors)
      return
    }
    setErrors({})
    // TODO(impl): POST /api/prod-quotes/search を呼ぶ
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        onSearch()
      }}
    >
      <fieldset>
        <legend>制作見積情報検索</legend>

        <label>
          ステータス
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            {PROD_QUOTE_STATUS_CODES.map((code) => (
              <option key={code} value={code}>
                {PROD_QUOTE_STATUS[code]}
              </option>
            ))}
          </select>
        </label>

        <label>
          見積書No
          <input value={quotNo} onChange={(e) => setQuotNo(e.target.value)} maxLength={20} />
          {errors.quotNo?.map((m) => (
            <span key={m} role="alert">
              {m}
            </span>
          ))}
        </label>

        <button type="submit">検索</button>
      </fieldset>
    </form>
  )
}
