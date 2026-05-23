import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AiFloatingButton extends StatelessWidget {
  final VoidCallback onTap;
  const AiFloatingButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}