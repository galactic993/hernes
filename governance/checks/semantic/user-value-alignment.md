# 司法（意味判定 / semantic）: user-value-alignment

> LLM で「意味」を裁く司法の仕様。MVP では**枠のみ（未配線）**。
> 本接続は行政(harness) の AGENT_CMD（`codex exec` / `claude -p` 等）経由で行う。

- id: `user-value-alignment`
- kind: `semantic`
- 憲法: **C1**（ユーザー価値が最優先）
- 入力: 変更 diff ＋ 紐づく `specs/<feature>/intent.yaml`（`intent.user_problem` / `intent.desired_outcome`）
- 判定: 変更がユーザー課題・期待成果に整合しているかを LLM が判定し、`{ verdict: pass|fail, reason }` を返す
- 状態: **未配線**（このファイルはチェックモジュールとして登録されない＝立法に束縛されない）

## なぜ MVP で未配線か

司法には2種類ある:

- **決定性チェック（deterministic）**: Grep / AST 等で機械判定（このリポジトリで実装済み・CI を落とす）
- **意味チェック（semantic）**: LLM で意味判定（非決定的・コストとレビューが要る）

MVP は決定性チェックで「書かれている→効いている」を先に確立する。意味チェックは
`severity: warn` の助言から段階導入し、安定したものだけ `error` に昇格する。
