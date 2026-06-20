import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

void listenAuthMessages(WidgetRef ref, BuildContext context) {
  ref.listen<AuthFormState>(authControllerProvider, (previous, next) {
    final messenger = ScaffoldMessenger.of(context);

    if (next.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      ref.read(authControllerProvider.notifier).clearMessages();
    }

    if (next.successMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(next.successMessage!)));
      ref.read(authControllerProvider.notifier).clearMessages();
    }
  });
}
