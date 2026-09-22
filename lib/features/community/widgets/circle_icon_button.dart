import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// A standalone circular icon button used in the Community header
/// (search / messages / notifications). Gives each icon its own tappable
/// surface with real spacing so adjacent icons can't be mis-tapped.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;
  final double size;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.showBadge = false,
    this.size = 39,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.75)),
          ),
          if (showBadge)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.cardSurface(context), width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
