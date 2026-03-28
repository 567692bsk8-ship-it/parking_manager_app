import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_user.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<AuthUser?> signInWithEmail(String email, String password);
  Future<AuthUser?> signUpWithEmail(
    String email,
    String password,
    String name,
    String role,
  );
  Future<AuthUser?> signInWithGoogle();
  Future<void> signOut();
  Stream<AuthUser?> watchCurrentUser(String uid);
  Future<AuthUser?> getCurrentUser(String uid);
  Future<void> syncUser(User user, {String? initialRole, String? displayName});
  Future<void> updateDisplayName(String uid, String name);
  Future<void> linkWithGoogle();
  Future<void> unlinkGoogle();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> updateEmail(String uid, String newEmail);
  Future<void> sendSignInLink(String email);
  Future<bool> isSignInWithEmailLink(String link);
  Future<AuthUser?> signInWithEmailLink(String email, String link);
  Stream<List<AuthUser>> getUsersByRoleStream(String role);
  Stream<int> getUserCountByRoleStream(String role);
  Future<void> signUpWithEmailAndSendReset(
    String email,
    String name,
    String role,
  );
  Future<String> verifyPasswordResetCode(String code);
  Future<void> confirmPasswordReset(String code, String newPassword);
  Future<AuthUser?> signInAnonymously();
  Future<AuthUser?> getManagerByCode(String code);
}

class AuthRepositoryImpl implements AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      return await getCurrentUser(credential.user!.uid);
    }
    return null;
  }

  @override
  Future<AuthUser?> signUpWithEmail(
    String email,
    String password,
    String name,
    String role,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      await credential.user!.updateDisplayName(name);
      await syncUser(credential.user!, initialRole: role);
      return await getCurrentUser(credential.user!.uid);
    }
    return null;
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider();
      // 余計なスコープが干渉することがあるため一旦最小限に
      googleProvider.addScope('email');
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      final UserCredential userCredential = await _auth.signInWithPopup(
        googleProvider,
      );

      final user = userCredential.user;
      if (user != null) {
        // 同期処理を待機
        await syncUser(user, displayName: user.displayName);
        // 最新のユーザー情報を取得
        return await getCurrentUser(user.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') return null;
      if (e.code == 'cancelled-popup-request') return null;

      String message = 'Googleサインインに失敗しました';
      switch (e.code) {
        case 'auth-domain-config-required':
          message = 'Firebaseコンソールの承認済みドメイン設定が必要です。';
          break;
        case 'operation-not-allowed':
          message = 'Googleサインインが有効になっていません。';
          break;
        case 'unauthorized-domain':
          message = 'このドメインは承認されていません。';
          break;
      }
      throw '$message (${e.code})';
    } catch (e) {
      throw 'サインイン中に予期せぬエラーが発生しました: $e';
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      // ignore
      await _auth.signOut();
    }
  }

  @override
  Stream<AuthUser?> watchCurrentUser(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return AuthUser.fromMap(doc.data()!, uid);
      }
      return null;
    });
  }

  @override
  Future<AuthUser?> getCurrentUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AuthUser.fromMap(doc.data()!, uid);
    }
    return null;
  }

  @override
  Future<void> syncUser(
    User user, {
    String? initialRole,
    String? displayName,
  }) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    final nameToSave = displayName ?? user.displayName;

    if (!doc.exists) {
      String? managerCode;
      if (initialRole == 'admin' || initialRole == 'dev') {
        managerCode =
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString();
      }

      final appUser = AuthUser(
        uid: user.uid,
        email: user.email ?? '',
        role: initialRole ?? 'user',
        displayName: nameToSave,
        photoUrl: user.photoURL,
        managerCode: managerCode,
      );
      await userDoc.set(appUser.toMap());
    } else {
      final existingData = doc.data() as Map<String, dynamic>;
      final Map<String, dynamic> updateData = {
        'display_name': nameToSave,
        'photo_url': user.photoURL,
        'updated_at': DateTime.now(),
      };

      // 管理者/開発者でコードがない場合は生成（既存ユーザー対応）
      final currentRole = existingData['role'];
      if ((currentRole == 'admin' || currentRole == 'dev') &&
          existingData['manager_code'] == null) {
        updateData['manager_code'] =
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString();
      }

      await userDoc.update(updateData);
    }
  }

  @override
  Future<void> updateDisplayName(String uid, String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    await _db.collection('users').doc(uid).update({
      'display_name': name,
      'updated_at': DateTime.now(),
    });
  }

  @override
  Future<void> linkWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'ログインしていません。';

      final googleProvider = GoogleAuthProvider();
      // 余計な権限を要求せず、メールアドレスの範囲のみに限定
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // linkWithPopup を使用。Web環境において最も安定している方法です。
      await user.linkWithPopup(googleProvider);

      await syncUser(user);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'credential-already-in-use':
          message = 'このGoogleアカウントは既に別のアカウントで使用されています。';
          break;
        case 'provider-already-linked':
          message = '既にGoogleアカウントと連携されています。';
          break;
        case 'requires-recent-login':
          message = 'セキュリティのため、一度サインアウトしてから再度お試しください。';
          break;
        case 'popup-closed-by-user':
          return;
        case 'auth-domain-config-required':
          message = 'Firebaseコンソールの認可ドメイン設定が必要です。';
          break;
        case 'cancelled-popup-request':
          return;
        default:
          message = 'Google連携に失敗しました(${e.code})';
      }
      throw message;
    } catch (e) {
      throw '予期せぬエラーが発生しました。ブラウザのポップアップがブロックされていないか確認してください。($e)';
    }
  }

  @override
  Future<void> unlinkGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 連携されているプロバイダを確認
      final isGoogle = user.providerData.any(
        (p) => p.providerId == 'google.com',
      );
      if (!isGoogle) return;

      await user.unlink('google.com');
      await _googleSignIn.signOut();

      try {
        await syncUser(user);
      } catch (syncError) {
        throw '連携解除は成功しましたが、Firestoreのユーザー情報の更新でエラーが発生しました。($syncError)';
      }
    } catch (e) {
      throw '連携解除に失敗しました: $e';
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'このメールアドレスを持つユーザーは見つかりませんでした。';
        case 'invalid-email':
          throw 'メールアドレスの形式が正しくありません。';
        default:
          throw 'パスワードリセットメールの送信に失敗しました(${e.code})';
      }
    } catch (e) {
      throw 'システムエラーが発生しました: $e';
    }
  }

  @override
  Future<void> updateEmail(String uid, String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'ログインしていません。';

      // 1. Firebase Authのメールアドレスを更新 (新しい方式)
      await user.verifyBeforeUpdateEmail(newEmail);

      // 2. Firestoreのドキュメントを更新
      await _db.collection('users').doc(uid).update({
        'email': newEmail,
        'updated_at': DateTime.now(),
      });
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'requires-recent-login':
          throw 'セキュリティのため、再ログインが必要です。一度ログアウトしてから再度お試しください。';
        case 'email-already-in-use':
          throw 'このメールアドレスは既に他のアカウントで使用されています。';
        case 'invalid-email':
          throw '無効なメールアドレス形式です。';
        default:
          throw 'メールアドレスの更新に失敗しました(${e.code})';
      }
    } catch (e) {
      throw 'システムエラーが発生しました: $e';
    }
  }

  @override
  Future<void> sendSignInLink(String email) async {
    final actionCodeSettings = ActionCodeSettings(
      url: 'https://parking-app-2859f.web.app/login', // ログイン画面に戻す
      handleCodeInApp: true,
      iOSBundleId: 'com.example.parkingApp',
      androidPackageName: 'com.example.parking_app',
      androidInstallApp: true,
      androidMinimumVersion: '12',
    );

    try {
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } catch (e) {
      throw '認証メールの送信に失敗しました: $e';
    }
  }

  @override
  Future<bool> isSignInWithEmailLink(String link) async {
    return _auth.isSignInWithEmailLink(link);
  }

  @override
  Future<AuthUser?> signInWithEmailLink(String email, String link) async {
    try {
      final credential = await _auth.signInWithEmailLink(
        email: email,
        emailLink: link,
      );
      if (credential.user != null) {
        await syncUser(credential.user!);
        return await getCurrentUser(credential.user!.uid);
      }
      return null;
    } catch (e) {
      throw 'ログインに失敗しました: $e';
    }
  }

  @override
  Stream<List<AuthUser>> getUsersByRoleStream(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AuthUser.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  @override
  Stream<int> getUserCountByRoleStream(String role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Future<void> signUpWithEmailAndSendReset(
    String email,
    String name,
    String role,
  ) async {
    try {
      // 1. ユーザー作成 (一時的な強力なパスワードを使用)
      final tempPassword = 'Temp${DateTime.now().millisecondsSinceEpoch}P@ss!';
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      if (credential.user != null) {
        // 2. プロフィール更新
        await credential.user!.updateDisplayName(name);

        // 3. Firestoreに同期 (ロールを付与)
        await syncUser(credential.user!, initialRole: role, displayName: name);

        // 4. パスワード設定用（リセット）メールを送信
        await _auth.sendPasswordResetEmail(email: email);

        // 5. サインアウト (createUserでサインインされるため)
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'このメールアドレスは既に登録されています。サインイン画面からパスワードリセットをお試しください。';
      }
      throw 'サインアップに失敗しました: ${e.message}';
    } catch (e) {
      throw 'エラーが発生しました: $e';
    }
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    return await _auth.verifyPasswordResetCode(code);
  }

  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  @override
  Future<AuthUser?> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) return null;

    final userDoc = _db.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    if (!doc.exists) {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));
      final managerCode = (100000 + (now.millisecondsSinceEpoch % 900000))
          .toString();

      final guestUser = {
        'uid': user.uid,
        'email': '',
        'display_name': 'ゲスト管理者',
        'role': 'admin',
        'is_guest': true,
        'manager_code': managerCode,
        'created_at': now,
        'expires_at': expiresAt,
      };
      await userDoc.set(guestUser);

      // ゲスト用にサンプルデータを作成
      await _createSampleData(user.uid, managerCode, expiresAt);
    }
    return await getCurrentUser(user.uid);
  }

  Future<void> _createSampleData(
    String uid,
    String managerCode,
    DateTime expiresAt,
  ) async {
    final batch = _db.batch();
    final lotDoc = _db.collection('parking_lots').doc();
    final lotId = lotDoc.id;

    // 1. サンプル駐車場
    batch.set(lotDoc, {
      'name': 'サンプル飯田駅前駐車場',
      'address': '長野県飯田市上飯田',
      'total_slots': 5,
      'manager_id': uid,
      'is_guest': true,
      'expires_at': expiresAt,
      'created_at': DateTime.now(),
    });

    // 2. サンプル区画
    for (int i = 1; i <= 5; i++) {
      final slotNumber = i.toString().padLeft(3, '0');
      final slotDocId = '${lotId}_$slotNumber';
      batch.set(_db.collection('slots').doc(slotDocId), {
        'lot_id': lotId,
        'slot_number': slotNumber,
        'price': 3000,
        'status': i == 1 ? 'contracted' : 'available',
        'manager_id': uid,
        'is_guest': true,
        'expires_at': expiresAt,
        'created_at': DateTime.now(),
      });
    }

    // 3. サンプル契約 (1番目の区画)
    final contractDoc = _db.collection('contracts').doc();
    batch.set(contractDoc, {
      'user_name': 'デモ 太郎',
      'user_id': 'demo_user',
      'phone_number': '090-0000-0000',
      'address': 'ゲスト市デモ町1-1',
      'slot_number': '001',
      'lot_id': lotId,
      'monthly_fee': 3000,
      'payment_day': 25,
      'payment_method': '振込',
      'status': 'active',
      'car_maker': 'トヨタ',
      'car_model': 'プリウス',
      'car_color': 'ホワイト',
      'car_number': '1234',
      'manager_id': uid,
      'is_guest': true,
      'expires_at': expiresAt,
      'created_at': DateTime.now(),
      'start_date': DateTime.now(),
    });

    await batch.commit();
  }

  @override
  Future<AuthUser?> getManagerByCode(String code) async {
    final snapshot = await _db
        .collection('users')
        .where('manager_code', isEqualTo: code)
        .where('role', isEqualTo: 'admin') // ルールの整合性のため追加
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return AuthUser.fromMap(doc.data(), doc.id);
    }
    return null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});
