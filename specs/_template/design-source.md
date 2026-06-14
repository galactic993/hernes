# 設計書ソース

> この機能の出典となる Excel 設計書を明記する。`make spec FEATURE=<id>` と
> `design-doc-reader` スキルがここを読み、`scripts/render-design.sh` で画像化して理解する。

## 画面設計書

- パス: `<例: ../workshop/hts/design-sample/02-02_x_xxx_画面設計書_xxxx.xlsx>`
- 主に読むシート: 画面概要 / イベント記述書 / 項目記述書 / 参照仕様 / メッセージ一覧
- レンダリング: `make design DESIGN=<上記パス>` → `design/rendered/<doc>/page-*.png`

## テーブル定義書

- パス: `<例: ../workshop/hts/design-sample/xx-テーブル定義書_xxxx.xlsx>`
- 主に読むシート: テーブル一覧 / <対象テーブル名>

## 対象範囲メモ

- この機能で扱う画面 / テーブル / イベント（EVENT No）を箇条書き
