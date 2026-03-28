import 'package:flutter_riverpod/flutter_riverpod.dart';

/// LIFFの接続設定を管理するプロバイダー
/// [useLiff] を true にすると、実際のLIFF初期化ロジックが走ります。
class LiffState {
  static const bool useLiff = false; // 開発時はfalseでモック動作

  final bool isInitialized;
  final String? displayName;
  final String? profileImageUrl;

  LiffState({
    required this.isInitialized,
    this.displayName,
    this.profileImageUrl,
  });
}

class LiffNotifier extends Notifier<LiffState> {
  @override
  LiffState build() {
    if (!LiffState.useLiff) {
      // モックデータ: ログイン済みの状態で開始
      return LiffState(
        isInitialized: true,
        displayName: '管理者（テスト用）',
        profileImageUrl: 'https://via.placeholder.com/150',
      );
    }

    // LIFFがOFFの場合の初期状態
    return LiffState(isInitialized: false);
  }

  /// 実際のLIFF初期化ロジック（useLiff = true の時のみ動作）
  Future<void> initLiff() async {
    if (!LiffState.useLiff) return;

    // 開発メモ: ここに実際のLIFF SDKを使った初期化を記述
    // await liff.init(...);

    state = LiffState(isInitialized: true, displayName: 'LINE ユーザー名');
  }
}

final liffProvider = NotifierProvider<LiffNotifier, LiffState>(() {
  return LiffNotifier();
});
