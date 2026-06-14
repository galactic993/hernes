# ADR-0002: Excel設計書は「画像化して視覚的に読む」

- Status: Accepted
- Date: 2026-06-13
- Deciders: 開発責任者

## Context

人手の Excel 設計書（画面設計書・テーブル定義書）を仕様/テストへ落としたい。
当初はセル値の JSON 抽出（openpyxl 等）を検討したが、これは設計の意味を取りこぼす。

## Decision

設計書の理解は **PDF を中継して大判・高解像度の画像にし、視覚的に読む** 方式に統一する。

- `scripts/render-design.sh`: LibreOffice で xlsx → PDF（既定 `SinglePageSheets`=1シート1ページの大判）、poppler(`pdftoppm`) で PDF → 高解像度 PNG（既定150dpi、`DPI=200` 等で上げる）。
- エージェント（vision）が画像を読み、`design-doc-reader` / `table-def-reader` スキルで spec/スキーマへ写経する。
- **ソースの .xlsx は読み取り専用**。ページサイズ変更（A2化など）を元ファイルに加えてはならない。

## Consequences

- 取りこぼさない: 画面概要シートの**埋め込みキャプチャ**、**I/Oフロー図**、結合セル、色の意味（黄=未記入, 青=ヘッダ）。
  - 実証: 制作見積書作成トップの画面設計書で、150dpi なら日本語も I/O図も鮮明に読めることを確認。JSON抽出ではLaravel連携のI/O図が完全に欠落していた。
- 依存が増える: LibreOffice + poppler が必要（CIでは別途用意 or 設計読取は手元で実施）。
- `SinglePageSheets` により 1シート=1枚の大判画像になり、A4細切れの再結合が不要。縦長シートは画像が縦に大きくなる（必要なら DPI を下げる / `SINGLE_PAGE=0`）。

## 検証で判明した重要事項（用紙の大判化について）

「A2化して高解像度PDF→画像」を狙って **openpyxl で用紙サイズを A2 に変えて保存し直すと、埋め込みの I/Oフロー図（シェイプ/SmartArt）が消える**ことを確認した（制作見積書作成トップの画面概要シートで実証。`xl/drawings` は残るが図形が描画されない）。
- 結論: **大判化は LibreOffice 側（`render-design.sh` の `SinglePageSheets`）でのみ行い、ソースは一切書き換えない。**
- headless での Basic マクロ/python-UNO による A2 ページスタイル上書きはこの環境では不安定だったため採用せず、`SinglePageSheets` + 高DPI を既定とする（図形・キャプチャを保持したまま大判・高解像度を達成できる）。
