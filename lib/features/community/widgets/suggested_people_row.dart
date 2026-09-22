import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../models/profile_summary.dart';
import '../providers/follow_provider.dart';
import 'follow_button.dart';
import 'initial_avatar.dart';

/// Horizontal "Suggested for you" row at the top of the Trending feed.
/// Silently renders nothing while loading, on error, or once there's
/// nobody left to suggest — this is a discovery nicety, not core feed
/// content, so it shouldn't ever block or visibly break the feed under it.
class SuggestedPeopleRow extends ConsumerWidget {
  const SuggestedPeopleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestedPeopleProvider);
    final cs = Theme.of(context).colorScheme;

    return suggestionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (people) {
        if (people.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUGGESTED FOR YOU',
                style: GoogleFonts.figtree(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.35),
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              // Measured on-device: avatar (40) + gaps (16) + name line
              // (~18) + FollowButton's compact padding+text (~29) + the
              // card's own 28 of vertical padding leaves only ~1px of
              // slack at 132 — overflowed by 2px in practice. 148 gives
              // real headroom instead of a razor-thin fit.
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: people.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) =>
                      _SuggestedPersonCard(person: people[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SuggestedPersonCard extends StatelessWidget {
  final ProfileSummary person;
  const _SuggestedPersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/community/user/${person.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InitialAvatar(name: person.displayName, size: 40),
            const SizedBox(height: 8),
            Text(
              person.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            FollowButton(
              targetUserId: person.id,
              serverIsFollowing: false,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
