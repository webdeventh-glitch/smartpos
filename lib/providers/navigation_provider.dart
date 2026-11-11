import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/app_routes.dart';

/// Holds the active workspace [AppRoute] rendered inside `MainShell`.
class NavigationNotifier extends Notifier<AppRoute> {
  @override
  AppRoute build() => AppRoute.dashboard;

  void goTo(AppRoute route) {
    if (state != route) {
      state = route;
    }
  }

  void goToPosForBusinessType(String businessType) {
    state = AppRoute.defaultPosWorkspaceForBusinessType(businessType);
  }

  void resetToDashboard() => state = AppRoute.dashboard;
}

final navigationProvider =
    NotifierProvider<NavigationNotifier, AppRoute>(NavigationNotifier.new);

