/**
 * 制作見積ステータス。
 * 出典: 編-テーブル定義書 / 制作見積シート No.7「prod_quot_status CHAR(2)」の注記。
 *   00:未着手 / 10:制作見積中 / 20:制作見積済 / 30:受取済 / 40:発行済 / 50:差戻
 */
export const PROD_QUOTE_STATUS_CODES = ['00', '10', '20', '30', '40', '50'] as const

export type ProdQuoteStatusCode = (typeof PROD_QUOTE_STATUS_CODES)[number]

export const PROD_QUOTE_STATUS: Record<ProdQuoteStatusCode, string> = {
  '00': '未着手',
  '10': '制作見積中',
  '20': '制作見積済',
  '30': '受取済',
  '40': '発行済',
  '50': '差戻',
}
