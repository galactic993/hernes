# design/source

Excel 設計書（画面設計書・テーブル定義書）の置き場。

- リポジトリに同梱してもよいし、外部（例: `../workshop/hts/design-sample/`）を参照してもよい。
- 各機能は `specs/<feature>/design-source.md` に**対象 Excel のパスとシート**を明記する。
- 画像化: `make design DESIGN=design/source/xxx.xlsx` → `design/rendered/<doc>/page-*.png`
- レンダリング結果（`design/rendered/`）は gitignore。`scripts/render-design.sh` で再生成できる。

依存（読むときだけ）: `brew install --cask libreoffice && brew install poppler`
