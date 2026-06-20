import 'package:flutter/material.dart';

import '../data/models/user_profile_model.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
  });

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String labelText;

    switch (role) {
      case UserRole.owner:
        backgroundColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        labelText = 'Pemilik (OWNER)';
        break;
      case UserRole.admin:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        labelText = 'Administrator (ADMIN)';
        break;
      case UserRole.kasir:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
        labelText = 'Kasir (KASIR)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        labelText.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
