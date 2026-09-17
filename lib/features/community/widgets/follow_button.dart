import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../providers/follow_provider.dart';

/// Compact Follow/Following toggle. `serverIsFollowing` is the value from
/// whatever list this button was rendered in (search results, following
/// list, profile screen); the notifier's optimistic override — shared by
/// [targetUserId] across every button on screen — takes precedence once
/// the user taps.
class FollowButton extends ConsumerWidget {
  final String targetUserId;
  final bool serverIsFollowing;
  final bool compact;

  const FollowButton({
    super.key,
    required this.targetUserId,
    required this.serverIsFollowing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(followNotifierProvider.notifier);
    final overrides = ref.watch(followNotifierProvider);
    final isFollowing = overrides[targetUserId] ?? serverIsFollowing;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        notifier.toggle(
          targetUserId: targetUserId,
          currentlyFollowing: isFollowing,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 6 : 9,
        ),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : AppColors.primary,
          border: Border.all(
            color: isFollowing
                ? cs.onSurface.withValues(alpha: 0.25)
                : AppColors.primary,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: GoogleFonts.figtree(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: isFollowing ? cs.onSurface.withValues(alpha: 0.6) : Colors.white,
          ),
        ),
      ),
    );
  }
}
