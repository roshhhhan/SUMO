# new_app1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Sumo Bracket App

This workspace contains two parts:

1. **Flutter client** located in the root `lib/` directory. The app lets you
   configure a bracket, enter team names, and score matches. It currently
   displays and scores single-elimination brackets; double-elimination is
   scaffolded but will require additional UI logic to show the losers' side.
2. **Dart backend** under the `server/` folder. It exposes a simple REST API
   backed by a MySQL database (works with XAMPP). The bracket structure is
   stored as JSON; scores are applied and winners propagate automatically. The
   `type` field in the JSON records whether the bracket was created as single
   or double elimination.

### Running the backend

1. Install XAMPP and start the MySQL service. By default XAMPP's root
   account has no password; if you changed it you'll need to supply the
   credentials to the Dart server. You can set `DB_USER` and `DB_PASS` either
   through environment variables or by editing `server/.env`—the example
   file shipped with this project uses `root` and an empty password.2. From a terminal run:
   ```bash
   cd server
   dart pub get
   dart run bin/server.dart
   ```
   You can also set environment variables in `server/.env` to customize the
   connection (DB_HOST, DB_USER, etc).
3. The server listens on port 8080 by default. Create brackets by POSTing to
   `http://localhost:8080/api/brackets`.

### Running the Flutter client

1. Make sure an emulator or device is available.
2. Run `flutter pub get` in the root directory (already done previously).
3. Execute `flutter run`. The app will start on the emulator and communicate
   with the local backend (Android emulator uses `10.0.2.2` address).

