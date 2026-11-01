import { useState } from "react";
import { ActivityIndicator, Pressable, Text, View } from "react-native";

import { supabase } from "@/lib/supabase";
import { styles } from "./SupabaseTestScreen.styles";

type ConnectionStatus = "idle" | "loading" | "success" | "error";

export default function SupabaseTestScreen() {
  const [status, setStatus] = useState<ConnectionStatus>("idle");
  const [message, setMessage] = useState("まだ接続テストを実行していません");

  const testConnection = async () => {
    setStatus("loading");
    setMessage("Supabaseに接続しています...");

    try {
      // profilesテーブルに読み取りリクエストを送信
      const { data, error } = await supabase
        .from("profiles")
        .select("id")
        .limit(1);

      if (error) {
        setStatus("error");
        setMessage(`接続エラー: ${error.message}`);
        return;
      }

      setStatus("success");
      setMessage(
        `Supabase APIから応答がありました。\n取得件数: ${data.length}件`,
      );
    } catch (error) {
      setStatus("error");
      setMessage(
        error instanceof Error
          ? error.message
          : "予期しないエラーが発生しました",
      );
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Supabase接続テスト</Text>

      <Text style={styles.description}>
        ボタンを押してSupabaseとの通信を確認します。
      </Text>

      <View style={styles.result}>
        {status === "loading" && <ActivityIndicator />}

        <Text style={styles.status}>
          {status === "success"
            ? "接続成功"
            : status === "error"
              ? "接続失敗"
              : status === "loading"
                ? "接続中"
                : "未確認"}
        </Text>

        <Text style={styles.message}>{message}</Text>
      </View>

      <Pressable
        style={styles.button}
        onPress={testConnection}
        disabled={status === "loading"}
      >
        <Text style={styles.buttonText}>
          {status === "loading" ? "接続中..." : "接続テスト"}
        </Text>
      </Pressable>
    </View>
  );
}
