import { PROD_QUOTE_STATUS, type ProdQuoteStatusCode, SCREEN_MESSAGES } from '@hernes/shared'

/**
 * 制作見積 検索結果一覧（FR-003: 行から詳細/作成へ遷移）。
 * メッセージ・ステータス表記は @hernes/shared を単一の出典とする。
 */
export interface ProdQuoteRow {
  prodQuotId: string
  quotNo: string
  customerName: string
  status: ProdQuoteStatusCode
}

export function SearchResults({
  rows,
  onNavigate,
}: {
  rows: ProdQuoteRow[]
  onNavigate: (prodQuotId: string) => void
}) {
  if (rows.length === 0) {
    // メッセージ一覧 No.6（区分: サクセス）
    return <output>{SCREEN_MESSAGES.SEARCH_NO_RESULT}</output>
  }
  return (
    <table>
      <thead>
        <tr>
          <th>見積書No</th>
          <th>得意先</th>
          <th>ステータス</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <tr key={r.prodQuotId}>
            <td>
              <button type="button" onClick={() => onNavigate(r.prodQuotId)}>
                {r.quotNo}
              </button>
            </td>
            <td>{r.customerName}</td>
            <td>{PROD_QUOTE_STATUS[r.status]}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
