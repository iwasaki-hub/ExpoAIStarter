# Supabase データベース設計

## 1. 方針
PostgreSQLを正規化した構造で使用する。全会計データは `business_id` に紐づけ、RLSで事業者の所有者のみがアクセスできるようにする。

## 2. テーブル一覧
| テーブル | 目的 |
|---|---|
| profiles | Supabase Authユーザーのプロフィール |
| businesses | 事業者・会計設定 |
| accounts | 勘定科目 |
| tax_categories | 消費税区分 |
| transactions | 簡単入力された取引 |
| journal_entries | 仕訳ヘッダー |
| journal_lines | 借方・貸方明細 |
| attachments | 領収書等のメタデータ |

## 3. 主な関連
- `profiles.id` → `auth.users.id`
- `businesses.user_id` → `profiles.id`
- `accounts.business_id` → `businesses.id`
- `transactions.business_id` → `businesses.id`
- `transactions.account_id` → `accounts.id`
- `journal_entries.transaction_id` → `transactions.id`
- `journal_lines.journal_entry_id` → `journal_entries.id`
- `journal_lines.account_id` → `accounts.id`
- `attachments.transaction_id` → `transactions.id`

## 4. 金額・日付
- 金額は `BIGINT` で円単位の整数として保存する。
- `amount_yen` は正の金額を保存し、借方・貸方は `journal_lines` で表現する。
- 取引日・仕訳日は `DATE` を使う。
- 登録日時・更新日時は `TIMESTAMPTZ` を使う。
- 通貨列を設ける場合も初期値・許容値は `JPY` に限定する。

## 5. 取引と仕訳
`transactions` はユーザーが入力した業務上の取引を表す。`journal_entries` と `journal_lines` は会計上の仕訳を表す。1つの取引に対して複数の仕訳（発生・決済・取消等）が紐づく場合があるため、transaction_idをjournal_entries側に持たせる。

## 6. 決済・一部入金への拡張
MVPでは簡単入力を優先するが、一部入金・分割決済に対応する際は `settlements` テーブルを追加する。
- id
- business_id
- transaction_id
- settled_on
- amount_yen
- settlement_account_id
- created_at

決済イベントごとに仕訳を生成する。初期SQLでは将来拡張のために取引の `payment_status` と `settled_on` を持たせているが、本格的な分割決済ではsettlementsへ移行する。

## 7. 仕訳整合性
各journal_lineは借方または貸方の一方だけに正の金額を持つ。仕訳全体の借方合計と貸方合計の一致は、複数行をまたぐため通常のCHECK制約では保証できない。仕訳確定RPCでトランザクション内検証を行い、確定済み仕訳の明細変更を制限する。

## 8. RLS
すべての事業者データに対し、`businesses.user_id = auth.uid()` を満たす場合のみアクセスを許可する。子テーブルは親のbusiness_idをたどって所有権を検証する。

## 9. マイグレーション運用
- SQLは `supabase/migrations/` でバージョン管理する。
- 適用前に開発用Supabaseでテストする。
- 既存データを破壊する変更は別マイグレーションで慎重に行う。
- 本番DBを手作業で直接変更しない。
