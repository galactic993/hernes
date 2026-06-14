import { useState } from 'react'
import { type Customer, CustomerSelectModal } from './CustomerSelectModal'
import { DetailModal } from './DetailModal'
import { SearchForm } from './SearchForm'
import { type ProdQuoteRow, SearchResults } from './SearchResults'

/**
 * 制作見積書作成<トップ画面> コンテナ。
 * 検索フォーム(FR-002) ＋ 一覧(FR-001/003) ＋ 得意先選択(FR-004) ＋ 詳細モーダル(FR-005) を束ねる。
 * データはプロップ注入（App が API から供給）。本コンテナはコンポーネント結線に集中する。
 */
export function ProdQuoteTop({
  initialRows = [],
  customers = [],
}: {
  initialRows?: ProdQuoteRow[]
  customers?: Customer[]
}) {
  const [rows] = useState<ProdQuoteRow[]>(initialRows)
  const [detailId, setDetailId] = useState<string | null>(null)
  const [customerOpen, setCustomerOpen] = useState(false)
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)

  return (
    <section>
      <SearchForm />

      <button type="button" onClick={() => setCustomerOpen(true)}>
        得意先選択
      </button>
      {selectedCustomer ? <p>選択得意先: {selectedCustomer.name}</p> : null}

      <SearchResults rows={rows} onNavigate={(id) => setDetailId(id)} />

      <DetailModal open={detailId !== null} title="制作見積 詳細" onClose={() => setDetailId(null)}>
        <p>制作見積ID: {detailId}</p>
      </DetailModal>

      <CustomerSelectModal
        open={customerOpen}
        customers={customers}
        onSelect={(c) => {
          setSelectedCustomer(c)
          setCustomerOpen(false)
        }}
        onClose={() => setCustomerOpen(false)}
      />
    </section>
  )
}
