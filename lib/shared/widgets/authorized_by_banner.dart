import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';

/// Compact strip indicating one-time process authorization by a permitted cashier/admin.
class AuthorizedByBanner extends StatelessWidget {
  final User user;
  final EdgeInsetsGeometry margin;

  const AuthorizedByBanner({
    super.key,
    required this.user,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 15, color: Color(0xFFB45309)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'One-Time Access • Authorized by $name',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF92400E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

