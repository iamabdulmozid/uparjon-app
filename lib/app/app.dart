import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/failure.dart';
import '../core/services/snackbar_service.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/password_reset_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class UparjonApp extends ConsumerWidget {
  const UparjonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth failures are announced once, here, rather than by every screen
    // that happens to watch the same provider.
    ref.listen(authControllerProvider, _showFailure);
    ref.listen(passwordResetControllerProvider, _showFailure);

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Uparjon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      scaffoldMessengerKey: SnackbarService.messengerKey,
    );
  }
}

void _showFailure(AsyncValue<Object?>? previous, AsyncValue<Object?> next) {
  final error = next.error;
  if (error is Failure) SnackbarService.showFailure(error);
}
