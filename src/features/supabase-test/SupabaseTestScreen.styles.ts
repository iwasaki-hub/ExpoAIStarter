import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
    justifyContent: "center",
    backgroundColor: "#F8FAFC",
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    marginBottom: 12,
    color: "#1E293B",
  },
  description: {
    fontSize: 15,
    color: "#64748B",
    marginBottom: 24,
  },
  result: {
    padding: 20,
    backgroundColor: "#FFFFFF",
    borderRadius: 12,
    marginBottom: 24,
    gap: 12,
  },
  status: {
    fontSize: 20,
    fontWeight: "bold",
    color: "#1E293B",
  },
  message: {
    fontSize: 14,
    color: "#475569",
    lineHeight: 22,
  },
  button: {
    backgroundColor: "#2563EB",
    padding: 16,
    borderRadius: 10,
    alignItems: "center",
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "bold",
  },
});
