import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

// サインアップ中のリダイレクト防止フラグ
final signingUpProvider = StateProvider<bool>((ref) => false);

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Firestoreから現在のユーザー情報をリアルタイムに監視
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchCurrentUser(user.uid);
});

// ユーザーのロールを別途提供
final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider).value?.role;
});

// 管理者ID（監視中または自分自身）
final viewingAdminIdProvider = StateProvider<String?>((ref) => null);

// 管理者ユーザー一覧の監視 (Dev用)
final adminUsersProvider = StreamProvider<List<AuthUser>>((ref) {
  return ref.watch(authRepositoryProvider).getUsersByRoleStream('admin');
});

// 契約者数のカウント (Dev用)
final totalContractorsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(authRepositoryProvider).getUserCountByRoleStream('user');
});

// 管理者数のカウント (Dev用)
final adminCountProvider = StreamProvider<int>((ref) {
  return ref.watch(authRepositoryProvider).getUserCountByRoleStream('admin');
});
