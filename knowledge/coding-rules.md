# コーディング規約・ファイル分割方針

## 1. 基本
- TypeScriptを使用する。
- Expo SDKに対応する依存関係は `npx expo install <package>` で導入する。
- Expo Routerのルートファイルは `src/app/` に置く。
- 画面固有の表示ロジック・イベント処理とスタイルを別ファイルに分ける。
- 会計計算ロジックを画面コンポーネントへ直接書かない。

## 2. 推奨構成
```text
src/
├── app/
│   ├── (tabs)/
│   │   ├── index.tsx
│   │   ├── transactions.tsx
│   │   ├── reports.tsx
│   │   └── settings.tsx
│   └── transactions/
│       ├── income.tsx
│       └── expense.tsx
├── features/
│   ├── dashboard/
│   │   ├── DashboardScreen.tsx
│   │   ├── DashboardScreen.styles.ts
│   │   └── components/
│   │       ├── SummaryCard.tsx
│   │       └── SummaryCard.styles.ts
│   ├── transactions/
│   │   ├── TransactionListScreen.tsx
│   │   ├── TransactionListScreen.styles.ts
│   │   ├── IncomeFormScreen.tsx
│   │   ├── IncomeFormScreen.styles.ts
│   │   ├── ExpenseFormScreen.tsx
│   │   └── ExpenseFormScreen.styles.ts
│   ├── accounting/
│   └── reports/
├── components/
├── theme/
│   ├── colors.ts
│   ├── spacing.ts
│   ├── typography.ts
│   └── index.ts
├── lib/
│   └── supabase/
├── services/
├── hooks/
├── types/
└── utils/
```

## 3. ファイル責務
- `*.tsx`：コンポーネント構造、表示、イベントの受け渡し
- `*.styles.ts`：StyleSheet.createによる見た目
- `theme/`：色・余白・文字・角丸等の共通トークン
- `features/*/services`：機能固有のデータアクセス
- `utils/`：純粋関数・金額フォーマット等
- `types/`：共有型定義

## 4. スタイル分離例
画面側：
```tsx
import { View, Text } from "react-native";
import { styles } from "./DashboardScreen.styles";

export function DashboardScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>今月の収支</Text>
    </View>
  );
}
```

スタイル側：
```ts
import { StyleSheet } from "react-native";
import { colors, spacing } from "@/theme";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: spacing.lg,
    backgroundColor: colors.background,
  },
  title: {
    color: colors.text,
    fontSize: 20,
    fontWeight: "700",
  },
});
```

## 5. 禁止・注意
- 画面ファイルに巨大なStyleSheetを埋め込まない。
- JSX内に複雑な会計計算を書かない。
- 金額を浮動小数点で保存・計算しない。
- `any` を安易に使わない。
- Supabaseのservice_roleキーをクライアントへ置かない。
- ルートファイルに画面全体の実装を詰め込まない。
- 画面のスタイル値を複数箇所へ重複定義しない。
