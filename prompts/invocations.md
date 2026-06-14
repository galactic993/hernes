# 招集プロンプト集

AI エージェントへ手で投げるプロンプト。`<feature>` は機能フォルダ名（例 `001-prod-quote-top`）に置換する。
`scripts/` がこれらを非対話で実行する。1ステップずつ手で回したいときはここをコピペする。

> パイプライン: `0 設計書読取 → A spec → B 曖昧さ → C 受入+テスト → D 計画 → E タスク → F 実装 → (G 修復) → H レビュー`

---

## 0. 設計書読み取り（Excel → 画像 → 視覚理解 → spec）

```text
design-doc-reader スキルを使う。
Feature: <feature>

specs/<feature>/design-source.md に書かれた Excel 画面設計書を
scripts/render-design.sh で PNG 化し、ページ画像を視覚的に読む。
（テーブル定義書は table-def-reader スキルで @hernes/db スキーマへ）

作成:
- specs/<feature>/intent.yaml（未作成なら下書き）
- specs/<feature>/spec.md

実装コードは書かない。各要件に出典（シート名・項目No・EVENT No）を併記する。
```

## A. 仕様化（補足 / 設計書が無い場合）

```text
intent-to-spec スキルを使う。
Feature: <feature>
docs/constitution.md と specs/<feature>/intent.yaml を読み、specs/<feature>/spec.md を作る。
実装コードは書かない。ビジネス判断を黙って解決しない。すべての要件をテスト可能にする。
```

## B. 曖昧さレビュー

```text
spec-clarifier スキルを使う。
Feature: <feature>
docs/constitution.md, specs/<feature>/intent.yaml, specs/<feature>/spec.md を読む。
specs/<feature>/questions.md を作成/更新し、課題を BLOCKER / MAJOR / MINOR で分類する。
BLOCKER があれば計画着手は不可と明記する。
```

## C. 受け入れ条件 + 失敗するテスト（TDD）

```text
acceptance-test-designer スキルを使う。
Feature: <feature>
specs/<feature>/spec.md, questions.md, AGENTS.md, design/rendered/ の設計書画像を読む。
specs/<feature>/acceptance.md と test-plan.md を作る。
MUST の条件のみ失敗するテストを追加（本番コードは書かない）。
メッセージ・規則は @hernes/shared を単一の出典とし、テストはそのメッセージ定数を検証する。
追加後 pnpm test を実行し、新規テストが期待通り失敗することを確認する。
```

## D. 実装計画

```text
あなたはシニアソフトウェアアーキテクト。
Feature: <feature>
AGENTS.md, docs/constitution.md, docs/architecture.md, specs/<feature>/{spec,acceptance,test-plan}.md を読む。
specs/<feature>/plan.md を作る。計画は最小限。新規依存は他に手が無い場合のみ。
データモデル・API・UI・セキュリティ・観測可能性・ロールバック・テスト戦略を含める。
```

## E. タスク分解

```text
Feature: <feature>
specs/<feature>/{spec,acceptance,plan}.md を読む。
specs/<feature>/tasks.md を作る。
各タスクは小さく独立検証可能、受け入れ条件に対応づけ、変更ファイルと検証コマンドを含む。
テストを実装より前に置く。
```

## F. 1タスク実装

```text
implementation-loop スキルを使う。
Feature: <feature>
specs/<feature>/tasks.md の「次の未完了タスク」だけを実装する。
AGENTS.md と docs/constitution.md に従う。
実装後: 最も狭い関連テスト → make verify → evidence.md 更新 → 検証が通ればタスク完了。
複数タスクを同時にやらない。
```

## G. 修復（検証失敗時）

```text
validation-repair-loop スキルを使う。
Feature: <feature>
直近のコマンド出力, specs/<feature>/{acceptance,evidence,loop-log}.md を読む。
根本原因を特定し、最小の修正を当てる。失敗テストを先に実行し、次に make verify。
同じ失敗が繰り返す/プロダクト判断が要る場合は停止してハンドオフを書く。
```

## H. リリースレビュー

```text
release-reviewer スキルを使う。
Feature: <feature>
git diff, specs/<feature>/{spec,acceptance,evidence}.md, CI 結果をレビューする。
準備状況・リスク・欠けている証跡・推奨を出す。
推奨は READY_FOR_MERGE / READY_FOR_STAGING_ONLY / NEEDS_HUMAN_REVIEW / BLOCKED のいずれか。
```
