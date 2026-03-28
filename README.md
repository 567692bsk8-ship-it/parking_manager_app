# 🚗 Parking Manager App (Parking Lot Management System)

月極駐車場管理をスマートにする、モダンなFlutter Web/Mobleアプリケーション。
Firebaseを活用したリアルタイムなデータ管理と、ゲストモードによるデモンストレーション機能を備えています。

## ✨ Key Features (主な機能)
- **リアルタイムダッシュボード**: 駐車場の全区画の稼働状況をグラフで一目で把握。
- **管理者・契約者双方の管理**: 契約情報の追加・編集、支払情報のトラッキング。
- **QRコード連携**: 管理者専用のQRコードで、外部デバイスからのアクセスや連携を容易に。
- **ゲストデモモード**: `https://.../guest` から、Firebase Anonymous Authを利用した1時間限定のデモ環境を即時体験可能。
- **マルチデバイス対応**: レスポンシブ設計により、PC/スマホどちらでも快適に操作可能。

## 🛠 Tech Stack (技術構成)
- **Frontend**: Flutter (3.x)
- **State Management**: Riverpod (v2)
- **Routing**: GoRouter
- **Backend**: Firebase (Authentication, Cloud Firestore, Firebase Hosting)
- **CI/CD**: GitHub Actions (Pushによる自動ビルド・デプロイ)

## 🚀 Demo (デモ)
こちらのURLから、インストール不要のゲストモードをお試しいただけます。
[https://parking-app-2859f.web.app/guest](https://parking-app-2859f.web.app/guest)
*(作成したデータは1時間後に自動消去されます)*

## 📦 How to build (ビルド方法)
1. Firebaseプロジェクトを作成し、`firebase_options.dart` を構成。
2. `flutter pub get`
3. `flutter build web`
4. `firebase deploy`
