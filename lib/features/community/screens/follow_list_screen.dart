import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../services/auth_service.dart';
import '../models/profile_summary.dart';
import '../providers/follow_provider.dart';
import '../widgets/follow_button.dart';
import '../widgets/initial_avatar.dart';

/// Followers/Following tabs for a profile (own or someone else's), reached
/// by tapping either count on UserProfileScreen or SettingsScreen. Backed
/// entirely by the existing `follows` table/RLS — read-only queries plus
/// the same FollowButton used everywhere else.
class FollowListScreen extends StatelessWidget {
  final String userId;
  final String displayName;
  final int initialTab;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.displayName,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back, size: 22, color: cs.onSurface),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                            fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TabBar(
                  tabs: const [Tab(text: 'Followers'), Tab(text: 'Following')],
                  labelStyle: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w400),
                  labelColor: cs.onSurface,
                  unselectedLabelColor: cs.onSurface.withValues(alpha: 0.4),
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: cs.outline.withValues(alpha: 0.4),
                  dividerHeight: 1,
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ConnectionsList(provider: followersListProvider(userId)),
                    _ConnectionsList(provider: followingListProvider(userId)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionsList extends ConsumerWidget {
  final AutoDisposeFutureProvider<List<ProfileSummary>> provider;
  const _ConnectionsList({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final peopleAsync = ref.watch(provider);

    return peopleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 32, color: cs.onSurface.withValues(alpha: 0.35)),
              const SizedBox(height: 12),
              Text(
                'Could not load this list.',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.invalidate(provider),
                child: Text(
                  'Try again',
                  style: GoogleFonts.figtree(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (people) {
        if (people.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 36, color: cs.onSurface.withValues(alpha: 0.18)),
                  const SizedBox(height: 16),
                  Text(
                    'Nobody here yet',
                    style: GoogleFonts.figtree(
                        fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: people.length,
          itemBuilder: (context, index) => _ConnectionRow(person: people[index]),
        );
      },
    );
  }
}

class _ConnectionRow extends ConsumerWidget {
  final ProfileSummary person;
  const _ConnectionRow({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final followingIds = ref.watch(followingIdsProvider).value ?? {};
    final isFollowing = followingIds.contains(person.id);
    final isMe = currentUserId == person.id;

    return GestureDetector(
      onTap: () {
        if (isMe) return;
        context.push('/community/user/${person.id}');
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            InitialAvatar(name: person.displayName, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                person.displayName,
                style: GoogleFonts.figtree(
                    fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ),
            if (!isMe && currentUserId != null) ...[
              const SizedBox(width: 8),
              FollowButton(
                targetUserId: person.id,
                serverIsFollowing: isFollowing,
                compact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
