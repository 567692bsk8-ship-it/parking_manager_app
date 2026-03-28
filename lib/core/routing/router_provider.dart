import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/contract_list_screen.dart';
import '../../features/admin/presentation/contract_detail_screen.dart';
import '../../features/admin/presentation/add_contract_screen.dart';
import '../../features/admin/presentation/edit_contract_screen.dart';
import '../../features/admin/presentation/parking_lot_list_screen.dart';
import '../../features/admin/presentation/parking_lot_slots_screen.dart';
import '../../features/admin/presentation/add_parking_lot_screen.dart';
import '../../features/admin/presentation/edit_parking_lot_screen.dart';
import '../../features/admin/data/contract_model.dart';
import '../../features/admin/data/parking_lot_model.dart';
import '../../features/admin/presentation/admin_list_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/auth_action_screen.dart';
import '../../features/auth/presentation/settings_screen.dart';
import '../../features/auth/presentation/guest_welcome_screen.dart';
import '../../features/user/presentation/user_home_screen.dart';
import '../../features/user/presentation/user_add_contract_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

// 滑らかなフェード遷移を定義
CustomTransitionPage<void> _fadeTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userRole = ref.watch(userRoleProvider);
  final isSigningUp = ref.watch(signingUpProvider);

  return GoRouter(
    initialLocation: '/admin',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isGuestPath = state.matchedLocation == '/guest';
      final isAuthLoading = authState.isLoading;

      // 1. サインアップ処理中、または読み込み中の場合はリダイレクトしない
      if (isSigningUp || isAuthLoading) return null;

      // 2. 未ログインの場合
      if (!isLoggedIn) {
        final isAuthAction = state.matchedLocation == '/auth/action';
        return (isLoggingIn || isAuthAction || isGuestPath) ? null : '/login';
      }

      // 3. ログイン済みでログイン画面またはゲスト画面にいる場合
      if (isLoggingIn || isGuestPath) {
        // ロールの読み込みを待つ
        if (userRole == null) return null;

        if (userRole == 'admin' || userRole == 'dev') return '/admin';
        return '/user/home';
      }

      // 4. ロールによるアクセス制御
      if (isLoggedIn && userRole != null) {
        final isAdminPath = state.matchedLocation.startsWith('/admin');
        final isUserPath = state.matchedLocation.startsWith('/user');

        if ((userRole == 'admin' || userRole == 'dev') && isUserPath) {
          // 管理者用設定画面などはOKとするか
          if (state.matchedLocation.contains('settings')) return null;
          return '/admin';
        }
        if (userRole == 'user' && isAdminPath) {
          return '/user/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const AuthScreen()),
      ),
      GoRoute(
        path: '/guest',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const GuestWelcomeScreen()),
      ),
      GoRoute(
        path: '/auth/action',
        pageBuilder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? '';
          final oobCode = state.uri.queryParameters['oobCode'] ?? '';
          return _fadeTransition(
            state: state,
            child: AuthActionScreen(mode: mode, oobCode: oobCode),
          );
        },
      ),
      GoRoute(
        path: '/user/home',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const UserHomeScreen()),
        routes: [
          GoRoute(
            path: 'contracts/add',
            pageBuilder: (context, state) => _fadeTransition(
              state: state,
              child: const UserAddContractScreen(),
            ),
          ),
        ],
      ),
      // 管理者用ルート（ダッシュボード）
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) {
          final adminId = state.uri.queryParameters['adminId'];
          return _fadeTransition(
            state: state,
            child: AdminDashboardScreen(adminId: adminId),
          );
        },
      ),
      // 契約者一覧
      GoRoute(
        path: '/admin/contracts',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const ContractListScreen()),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) {
              final lotId = state.uri.queryParameters['lotId'];
              final slotNumber = state.uri.queryParameters['slotNumber'];
              return _fadeTransition(
                state: state,
                child: AddContractScreen(
                  initialLotId: lotId,
                  initialSlotNumber: slotNumber,
                ),
              );
            },
          ),
          GoRoute(
            path: 'detail',
            pageBuilder: (context, state) {
              final contract = state.extra as Contract;
              return _fadeTransition(
                state: state,
                child: ContractDetailScreen(contract: contract),
              );
            },
          ),
          GoRoute(
            path: 'edit',
            pageBuilder: (context, state) {
              final contract = state.extra as Contract;
              return _fadeTransition(
                state: state,
                child: EditContractScreen(contract: contract),
              );
            },
          ),
        ],
      ),
      // 管理者一覧 (Devロール用)
      GoRoute(
        path: '/admin/admins',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const AdminListScreen()),
      ),
      // 駐車場一覧
      GoRoute(
        path: '/admin/parking_lots',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const ParkingLotListScreen()),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) => _fadeTransition(
              state: state,
              child: const AddParkingLotScreen(),
            ),
          ),
          GoRoute(
            path: 'slots',
            pageBuilder: (context, state) {
              final lot = state.extra as ParkingLot;
              return _fadeTransition(
                state: state,
                child: ParkingLotSlotsScreen(parkingLot: lot),
              );
            },
          ),
          GoRoute(
            path: 'edit',
            pageBuilder: (context, state) {
              final lot = state.extra as ParkingLot;
              return _fadeTransition(
                state: state,
                child: EditParkingLotScreen(parkingLot: lot),
              );
            },
          ),
        ],
      ),
      // 設定画面（管理者・開発共通）
      GoRoute(
        path: '/admin/settings',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const SettingsScreen()),
      ),
      // 設定画面（利用者用）
      GoRoute(
        path: '/user/settings',
        pageBuilder: (context, state) =>
            _fadeTransition(state: state, child: const SettingsScreen()),
      ),
    ],
  );
});
