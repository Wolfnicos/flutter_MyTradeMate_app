class EnvConfig {
  static const bool liveTradingEnabled =
      bool.fromEnvironment('LIVE_TRADING', defaultValue: false);
  static const int recvWindowMs =
      int.fromEnvironment('RECV_WINDOW_MS', defaultValue: 5000);
}
