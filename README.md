# ExpoAIStarter — 会計アプリ設計パック

日本の個人事業主向け会計アプリの設計資料と、Supabase初期データベース用SQLです。

## 前提
- 対象：日本の個人事業主
- 通貨：日本円（JPY）のみ
- 会計期間：1月1日〜12月31日
- 申告方式：青色申告・白色申告
- 入力：簡単入力。内部では複式簿記の仕訳を保持
- クライアント：Expo / React Native / TypeScript
- バックエンド：Supabase / PostgreSQL
- デザイン：画面・コンポーネントごとに `*.styles.ts` へ分離

## 収録内容
- `knowledge/requirements.md`：要件定義
- `knowledge/detailed-design.md`：アプリ詳細設計
- `knowledge/database-design.md`：データベース設計
- `knowledge/accounting-rules.md`：自動仕訳・会計ルール
- `knowledge/security.md`：セキュリティ設計
- `knowledge/coding-rules.md`：ソースコード構成・デザイン分離規約
- `knowledge/testing.md`：テスト方針
- `supabase/migrations/001_initial_schema.sql`：初期テーブル・RLS・基本制約
- `docs/ERD.md`：ER図（Mermaid）

## GitHubへの追加方法
1. ZIPを展開します。
2. 展開したフォルダ内の `knowledge`、`supabase`、`docs`、`README.md` を、既存の `ExpoAIStarter` リポジトリのルートへコピーします。
3. VS Codeで差分を確認します。
4. GitHub Desktopで変更内容を確認し、コミットしてPushします。

## Supabase SQLの適用
このSQLは初期スキーマ案です。まずSupabaseの開発用プロジェクトで適用し、テーブル・制約・RLSポリシーを確認してください。本番プロジェクトへ適用する前に、必ずテストとレビューを行ってください。

Supabase DashboardのSQL Editorで `supabase/migrations/001_initial_schema.sql` の内容を実行する方法、またはSupabase CLIのmigrationとして管理する方法があります。既存の同名テーブルがある環境にはそのまま実行しないでください。

## 重要な設計上の注意
- このSQLはデータベースの土台を作るものです。取引登録と仕訳生成を原子的に行うRPC/サーバー処理は次の実装ステップで追加します。
- 借方合計＝貸方合計は行単位のCHECK制約だけでは保証できません。仕訳確定処理（RPC）でトランザクション内検証を行います。
- 税務申告書の自動作成・税額計算は、この初期SQLの対象外です。対象年の法令・国税庁資料に照らした別途の要件確認が必要です。
- Supabaseの `service_role` キーをアプリに含めないでください。
