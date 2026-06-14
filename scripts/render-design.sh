#!/usr/bin/env bash
#
# render-design.sh — Excel設計書を「PDF中継 → 高解像度PNG」で画像化する（設計書理解の中核ツール）。
#
# 方針（重要・実証済み）:
#   - セル値抽出ではなく、シートを「見たまま」画像化する。
#   - xlsx → PDF → PNG と必ず PDF を中継する。PDF段階で大判化することで高解像度の画像が得られる。
#   - 既定では SinglePageSheets（1シート=1ページ）で出力する。A4で細切れにならず、
#     1シートを1枚の大判画像として通して読める。
#   - !!! ソースの .xlsx を openpyxl 等で書き換えてページサイズを変えてはいけない !!!
#       → 埋め込みの I/Oフロー図・SmartArt・シェイプが保存時に消える（検証で確認）。
#         用紙の大判化は LibreOffice 側（このスクリプト）でのみ行い、元ファイルは触らない。
#
# 依存: LibreOffice (soffice) と poppler (pdftoppm)
#   macOS: brew install --cask libreoffice && brew install poppler
#
# 使い方:
#   scripts/render-design.sh <xlsx> [out_dir]
#   DPI=200 scripts/render-design.sh <xlsx>          # 解像度を上げる（既定150）
#   SINGLE_PAGE=0 scripts/render-design.sh <xlsx>    # シートの印刷設定どおりに分割（大判化しない）
#   make design DESIGN=path/to/設計書.xlsx
#
set -euo pipefail

SRC="${1:?usage: scripts/render-design.sh <xlsx> [out_dir]}"
[ -f "$SRC" ] || { echo "ファイルが見つかりません: $SRC" >&2; exit 2; }

DPI="${DPI:-150}"
SINGLE_PAGE="${SINGLE_PAGE:-1}"   # 1=1シート1ページ（大判・推奨） / 0=印刷設定どおり
SOFFICE="${SOFFICE:-soffice}"
command -v "$SOFFICE" >/dev/null 2>&1 || SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
command -v "$SOFFICE" >/dev/null 2>&1 || { echo "soffice が無い。brew install --cask libreoffice" >&2; exit 3; }
command -v pdftoppm  >/dev/null 2>&1 || { echo "pdftoppm が無い。brew install poppler" >&2; exit 3; }

if [ "$SINGLE_PAGE" = "1" ]; then
  # 各シートを1ページに収める（大判化）。図形・キャプチャはネイティブ描画され保持される。
  FILTER='pdf:calc_pdf_Export:{"SinglePageSheets":{"type":"boolean","value":"true"}}'
else
  FILTER='pdf'
fi

base="$(basename "$SRC")"; base="${base%.*}"
OUT="${2:-design/rendered/$base}"
mkdir -p "$OUT"
tmp="$(mktemp -d)"

echo "==> PDF変換: ${base} (SINGLE_PAGE=${SINGLE_PAGE})"
"$SOFFICE" --headless -env:UserInstallation="file://$tmp/lo" \
  --convert-to "$FILTER" --outdir "$OUT" "$SRC" >/dev/null 2>&1

pdf="$OUT/$base.pdf"
[ -f "$pdf" ] || { echo "PDF変換に失敗しました" >&2; exit 4; }

echo "==> PNG化 @${DPI}dpi"
pdftoppm -png -r "$DPI" "$pdf" "$OUT/page"

n=$(find "$OUT" -name 'page-*.png' | wc -l | tr -d ' ')
echo "==> 完了: $OUT （$n ページ / PDF: $base.pdf）"
echo "    次の手順: 画像を Read/vision で読み、設計書を理解して spec/テストへ写経する。"
echo "    ヒント: 文字が小さければ DPI=200 で再実行。1シートが巨大すぎる場合は SINGLE_PAGE=0。"
