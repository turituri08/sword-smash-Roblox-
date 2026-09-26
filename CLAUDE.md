# CLAUDE.md

このファイルは、このプロジェクトで作業するときに毎回読むこと。

- ゲームの仕様は `SwordSmash 仕様書.md` を参照する。
- スクリプトは `scripts/` 以下の `.lua` ファイルでも管理する（git管理用の写し）。`scripts/` はStudio上の配置をそのまま映したフォルダ構成にする（例: `ReplicatedStorage > Shared > CombatConfig` → `scripts/ReplicatedStorage/Shared/CombatConfig.lua`）。変更したい場合はまず変更内容をユーザーに提案して確認を取り、OKが出たらClaudeが直接編集する。
- スクリプトは1ファイル1責務で分割し、ModuleScriptは状態を持たせない。調整値は `CombatConfig` に集約する。置き場所の決め方などの詳細は仕様書の「フォルダ構成の方針と意図」に従う。
- Roblox StudioはMCPサーバー（`Roblox_Studio`）で接続済み。Studio上のScriptやエクスプローラーを変更するときも同じく提案→OK→編集の順で行い、Scriptを変更したら `scripts/` の写しも同じ内容に更新する。
- このフォルダはgitで管理している（作業ブランチは `develop`）。区切りの良いところで作業を一旦止め、変更内容の要約とコミットメッセージ案を提示する。ユーザーのOKが出たらコミットする。
- Studio上のスクリプトを新規作成・編集する際は、可読性を優先し、コードの意図や挙動（特に非自明な部分：物理演算の癖、順序に意味がある処理、回避策など）を簡潔にコメントで残すこと。すべての行を説明する必要はなく、読めば分かることにはコメントを付けない。
