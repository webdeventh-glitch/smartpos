import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Reactive wrapper around [AuthService.currentUserNotifier] for Riverpod consumers.
class AuthNotifier extends Notifier<User?> {
  @override
  User? build() {
    void listener() {
      state = AuthService.currentUser;
    }

    AuthService.currentUserNotifier.addListener(listener);
    ref.onDispose(
        () => AuthService.currentUserNotifier.removeListener(listener));
    return AuthService.currentUser;
  }

  void refresh() => state = AuthService.currentUser;

  Future<void> logout() async {
    await AuthService.logout();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(AuthNotifier.new);
