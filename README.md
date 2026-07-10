# Codex PreCompact Reflection

Codexがコンテキストを圧縮する直前に、そのセッションの反省点を別のCodexへまとめさせ、作業ディレクトリの `反省点` フォルダーへMarkdownで保存するPreCompact hookです。

## 導入方法

1. [Releases](https://github.com/leopoko/Codex_Precompact_Reflection/releases) から最新のZIPを取得して展開します。
2. 展開した `.codex` フォルダーを、hookを使うGitプロジェクトのルートへコピーします。
3. そのプロジェクトでCodexを新しく起動します。
4. Codexで `/hooks` を開き、`PreCompact` hookを有効化して信頼します。

これで自動圧縮時と `/compact` 実行時の両方で動作します。登録前から開いていたセッションはhook設定を読み直さないため、必ず新しいセッションを開始してください。

## 起動確認

Codexで次を確認します。

1. `/hooks` に `Writing session reflection before compaction` が表示され、有効になっていること。
2. `/compact` 実行時に同じステータスメッセージが表示されること。
3. 実行後、プロジェクト直下の `反省点` にMarkdownが作られること。

失敗時は次のログを確認してください。

- `.codex/hooks/precompact-reflection.log`: hook本体のエラー
- `.codex/hooks/precompact-reflection-child.log`: 子Codexの実行結果

hookが `/hooks` に出ない場合は、プロジェクトがGitリポジトリであること、Codexをプロジェクト内から起動したこと、プロジェクトを信頼済みであることを確認してください。hooks機能を明示的に無効化している場合は、`~/.codex/config.toml` に次を設定します。

```toml
[features]
hooks = true
```

## プロンプトの変更

反省内容は [`.codex/hooks/prompt.md`](.codex/hooks/prompt.md) を普通の文章として編集するだけで変更できます。PowerShellやJSONの編集は不要です。

hookは固定プロンプトの後ろへ追記型のセッショントランスクリプトを渡します。同じプロンプトと共通するトランスクリプト接頭辞は、OpenAI側の自動プロンプトキャッシュが利用可能な場合に再利用されます。キャッシュヒットは保証されず、コンテキスト上限自体を増やす機能でもありません。

## 動作の仕組み

- `PreCompact` が `manual` または `auto` で発生するとPowerShellスクリプトを実行します。
- hook入力の `transcript_path` からセッション全体を読みます。
- `codex exec` を `workspace-write`、`--ephemeral`、hooks無効で起動します。
- 子Codexが `反省点/yyyyMMdd-HHmmss-<session-id>.md` を作成します。
- 子Codexでhooksを無効化するため、再帰実行しません。

トランスクリプト全体が別のモデルリクエストへ送られるため、通常のCodex利用量を消費します。

## 必要環境

- Windows PowerShell 5.1以降
- PATH上にあり、ログイン済みの `codex` コマンド
- command hook対応のCodex CLI（開発時確認: `codex-cli 0.144.1`）
- Gitリポジトリ内での利用

## 開発・テスト

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test-hook.ps1
```

このテストはhook設定、入力解析、引数構築を検証し、Codex APIは呼びません。

## リリース

`v` で始まるタグをpushすると、GitHub Actionsが配布用ZIPとSHA-256ファイルを作り、GitHub Releaseへ自動添付します。

```powershell
git tag v1.0.0
git push origin v1.0.0
```

## License

[MIT](LICENSE)
