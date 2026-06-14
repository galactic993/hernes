// @vitest-environment jsdom
import { FIELD_MESSAGES, SCREEN_MESSAGES } from '@hernes/shared'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { CustomerSelectModal } from '../src/features/prod-quote/CustomerSelectModal'
import { DetailModal } from '../src/features/prod-quote/DetailModal'
import { SearchResults } from '../src/features/prod-quote/SearchResults'

afterEach(cleanup)

describe('SearchResults（FR-003 / AC-008）', () => {
  it('行の見積書No クリックで onNavigate(id) を呼ぶ', () => {
    const onNavigate = vi.fn()
    render(
      <SearchResults
        rows={[{ prodQuotId: '7', quotNo: 'Q-7', customerName: '得意先A', status: '00' }]}
        onNavigate={onNavigate}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Q-7' }))
    expect(onNavigate).toHaveBeenCalledWith('7')
  })

  it('結果なしは共有メッセージ(SEARCH_NO_RESULT)を表示する', () => {
    render(<SearchResults rows={[]} onNavigate={() => {}} />)
    expect(screen.getByRole('status').textContent).toBe(SCREEN_MESSAGES.SEARCH_NO_RESULT)
  })
})

describe('DetailModal（FR-005 / AC-009）', () => {
  it('open=false では描画されない', () => {
    render(<DetailModal open={false} title="詳細" onClose={() => {}} />)
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('open=true で表示し、閉じるで onClose を呼ぶ', () => {
    const onClose = vi.fn()
    render(<DetailModal open title="制作見積 詳細" onClose={onClose} />)
    expect(screen.queryByRole('dialog')).not.toBeNull()
    fireEvent.click(screen.getByRole('button', { name: '閉じる' }))
    expect(onClose).toHaveBeenCalled()
  })
})

describe('CustomerSelectModal（FR-004）', () => {
  it('不正な得意先コードは共有メッセージのエラーを出す', () => {
    render(<CustomerSelectModal open customers={[]} onSelect={() => {}} onClose={() => {}} />)
    fireEvent.change(screen.getByLabelText('得意先コード'), { target: { value: 'abc' } })
    fireEvent.click(screen.getByRole('button', { name: '検索' }))
    expect(screen.getByRole('alert').textContent).toBe(FIELD_MESSAGES.CUSTOMER_CODE_DIGITS_ONLY)
  })

  it('得意先を選択すると onSelect(customer) を呼ぶ', () => {
    const onSelect = vi.fn()
    const customer = { code: '12345', name: '得意先X' }
    render(
      <CustomerSelectModal open customers={[customer]} onSelect={onSelect} onClose={() => {}} />,
    )
    fireEvent.click(screen.getByRole('button', { name: /得意先X/ }))
    expect(onSelect).toHaveBeenCalledWith(customer)
  })
})
