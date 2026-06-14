#!/usr/bin/env bash
#
# new-feature.sh — feature フォルダを決定論的にブートストラップする。
#   specs/_template をコピーし、次の連番(NNN)を採番し、design-source.md に設計書パスを焼き込む。
#   design-to-pr スキル（および手動運用）の最初の1歩を、採番ミス・パス取り違えなしで固定するための薄いツール。
#
# 使い方:
#   scripts/new-feature.sh --slug <slug> [--screen <画面設計書.xlsx>] [--table <テーブル定義書.xlsx>] [--title <一文>]
#
# 例:
#   scripts/new-feature.sh \
#     --slug prod-quote-top \
#     --screen "../workshop/hts/design-sample/02-02_2_編-制作見積-制作見積書作成トップ_画面設計書_1007.xlsx" \
#     --table  "../workshop/hts/design-sample/編-テーブル定義書_1012.xlsx" \
#     --title  "制作見積書作成トップ画面"
#
# 出力: 作成した feature フォルダのパスを **最終行に** 標準出力する（呼び出し側が capture できる）。
#   既に同名フォルダがあれば作らずに終了コード 3（resume は呼び出し側が判断する）。
#
set -euo pipefail

SLUG=""; SCREEN=""; TABLE=""; TITLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --slug)   SLUG="${2:?--slug の値が無い}"; shift 2;;
    --screen) SCREEN="${2:?--screen の値が無い}"; shift 2;;
    --table)  TABLE="${2:?--table の値が無い}"; shift 2;;
    --title)  TITLE="${2:?--title の値が無い}"; shift 2;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) echo "不明な引数: $1" >&2; exit 2;;
  esac
done

[ -n "$SLUG" ] || { echo "--slug は必須（例: --slug prod-quote-top）" >&2; exit 2; }
[ -d specs/_template ] || { echo "specs/_template が無い。リポジトリのルートで実行する。" >&2; exit 2; }

# 設計書パスは存在チェック（指定された場合のみ）。早めに気づくほど安い。
[ -z "$SCREEN" ] || [ -f "$SCREEN" ] || { echo "画面設計書が見つからない: $SCREEN" >&2; exit 4; }
[ -z "$TABLE" ]  || [ -f "$TABLE" ]  || { echo "テーブル定義書が見つからない: $TABLE" >&2; exit 4; }

# 同じ slug の feature が既にあれば、新規作成せず既存パスを返す（連番を増やして重複させない）。
# 呼び出し側（design-to-pr）は exit 3 を「resume せよ」の合図として扱う。
existing="$(find specs -maxdepth 1 -type d -name "[0-9][0-9][0-9]-${SLUG}" 2>/dev/null | head -1 || true)"
if [ -n "$existing" ]; then
  echo "同じ slug の feature が既にある: ${existing} （新規作成しない。resume は呼び出し側で判断）" >&2
  echo "${existing}"
  exit 3
fi

# 次の連番(NNN)を採番する。
last="$(find specs -maxdepth 1 -type d -name '[0-9][0-9][0-9]-*' 2>/dev/null \
        | sed 's#.*/##' | grep -oE '^[0-9]{3}' | sort -n | tail -1 || true)"
if [ -z "$last" ]; then next="001"; else next="$(printf '%03d' "$((10#$last + 1))")"; fi

FEATURE="${next}-${SLUG}"
DIR="specs/$FEATURE"

cp -r specs/_template "$DIR"

# design-source.md を実パスで上書き（null は明示）。intent.yaml は phase 0 で design-doc-reader が下書きする。
{
  echo "# 設計書ソース — ${TITLE:-$SLUG}"
  echo ""
  echo "> この機能の出典となる Excel 設計書。design-to-pr / design-doc-reader / table-def-reader が読む。"
  echo "> 画像化: \`make design DESIGN=<下記パス>\` → \`design/rendered/<doc>/page-*.png\`"
  echo ""
  echo "## 画面設計書"
  echo ""
  if [ -n "$SCREEN" ]; then
    echo "- パス: \`$SCREEN\`"
  else
    echo "- パス: null（この機能に画面設計書は無い）"
  fi
  echo "- 主に読むシート: 画面概要 / イベント記述書 / 項目記述書 / 参照仕様 / メッセージ一覧"
  echo ""
  echo "## テーブル定義書"
  echo ""
  if [ -n "$TABLE" ]; then
    echo "- パス: \`$TABLE\`"
  else
    echo "- パス: null（この機能にテーブル定義書は無い）"
  fi
  echo "- 主に読むシート: テーブル一覧 / <対象テーブル名>"
  echo ""
  echo "## 対象範囲メモ"
  echo ""
  echo "- 扱う画面 / テーブル / イベント(EVENT No) を箇条書き（phase 0 で更新）"
} > "$DIR/design-source.md"

echo "==> 作成: $DIR" >&2
echo "    design-source.md に設計書パスを記入済み。次は phase 0（make design → 視覚読取）。" >&2
echo "$DIR"
