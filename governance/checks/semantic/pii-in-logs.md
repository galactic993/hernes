# 司法（意味判定 / semantic）: pii-in-logs

> 個人情報（PII）のログ出力を LLM が意味判定で裁く司法の仕様。
> 決定性チェック（no-secret-in-logs）は固定の秘密 env 識別子のみをカバーするため、
> 「氏名・メール・電話・検索結果の中身」等の PII は本質的に意味判定が要る。

- id: `pii-in-logs`
- kind: `semantic`
- 憲法: **C5**（セキュリティとプライバシー）／ 立法: **R003**
- 入力: 変更 diff のうち console / logger 呼び出し、および紐づく `specs/<feature>/acceptance.md` の却下条件
- 判定: ログに個人情報（氏名・メール・電話・住所・検索結果レコードの中身等）が渡っていないかを LLM が判定し、
  `{ verdict: pass|fail, reason }` を返す
- 状態: **配線済み（既定 skip）**。`GOVERN_SEMANTIC=1` かつ `AGENT_CMD` 設定で有効化。安定後に warn→error 昇格。
