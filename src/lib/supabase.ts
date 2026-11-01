// React NativeでURLを扱うためのPolyfill
import "react-native-url-polyfill/auto";

// iPhoneにログイン状態を保存するための設定
import "expo-sqlite/localStorage/install";

import { createClient } from "@supabase/supabase-js";

// .envからSupabaseの接続情報を取得
const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabasePublishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

// 環境変数の設定漏れをチェック
if (!supabaseUrl || !supabasePublishableKey) {
  throw new Error(
    "Supabaseの環境変数が設定されていません。.envを確認してください。",
  );
}

// Supabaseクライアントを作成
export const supabase = createClient(supabaseUrl, supabasePublishableKey, {
  auth: {
    // ログインセッションを端末に保存
    storage: localStorage,

    // アクセストークンを自動更新
    autoRefreshToken: true,

    // セッションをアプリ再起動後も保持
    persistSession: true,

    // ネイティブアプリではURLからのセッション検出を無効化
    detectSessionInUrl: false,
  },
});
