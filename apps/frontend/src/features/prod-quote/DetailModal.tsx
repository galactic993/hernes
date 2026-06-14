import type { ReactNode } from 'react'

/**
 * 詳細モーダル（FR-005: 見積情報詳細・制作見積内容詳細をモーダル表示）。
 */
export function DetailModal({
  open,
  title,
  children,
  onClose,
}: {
  open: boolean
  title: string
  children?: ReactNode
  onClose: () => void
}) {
  if (!open) return null
  return (
    <dialog open aria-label={title}>
      <h2>{title}</h2>
      <div>{children}</div>
      <button type="button" onClick={onClose}>
        閉じる
      </button>
    </dialog>
  )
}
