import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../services/auth_service.dart';
import '../models/community_post.dart';
import '../providers/follow_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/follow_button.dart';
import '../widgets/initial_avatar.dart';
import '../widgets/situation_tag_chip.dart';
import '../widgets/user_actions_menu.dart';

/// Public view of another user's profile — Follow, message, block/report,
/// and their posts. Distinct from SettingsScreen, which is the current
/// user's own profile/editing surface.
class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final postsAsync = ref.watch(userPostsProvider(userId));
    final followingIds = ref.watch(followingIdsProvider).value ?? {};
    final isFollowing = followingIds.contains(userId);
    final followerCount = ref.watch(followerCountProvider(userId));
    final followingCount = ref.watch(followingCountProvider(userId));

    if (currentUser != null && currentUser.id == userId) {
      // Redirect self-views to the real profile/settings screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.canPop()) context.pop();
      });
    }

    // Always-visible header — independent of profileAsync's state, so the
    // user is never stuck looking at a bare spinner or a small unstyled
    // line of error text with no way back. Previously this header lived
    // only inside the `data:` branch of profileAsync.when(...).
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Icon(Icons.arrow_back, size: 22, color: cs.onSurface),
          ),
          const Spacer(),
          if (currentUser != null)
            UserActionsMenu(
              targetUserId: userId,
              targetDisplayName:
                  profileAsync.valueOrNull?['display_name'] as String? ??
                      'this user',
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, st) => _ErrorState(
                  message: 'Could not load this profile.\n${e.toString()}',
                  onRetry: () => ref.invalidate(publicProfileProvider(userId)),
                ),
                data: (profile) {
                  if (profile == null) {
                    return _ErrorState(
                      message: 'This profile is unavailable.',
                      onRetry: () =>
                          ref.invalidate(publicProfileProvider(userId)),
                    );
                  }
                  final displayName =
                      profile['display_name'] as String? ?? 'Anonymous';

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InitialAvatar(name: displayName, size: 64),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: GoogleFonts.epilogue(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => context.push(
                                                '/community/user/$userId/connections',
                                                extra: {
                                                  'displayName': displayName,
                                                  'initialTab': 0,
                                                },
                                              ),
                                              child: _CountLabel(
                                                  label: 'followers',
                                                  value: followerCount.value),
                                            ),
                                            const SizedBox(width: 14),
                                            GestureDetector(
                                              onTap: () => context.push(
                                                '/community/user/$userId/connections',
                                                extra: {
                                                  'displayName': displayName,
                                                  'initialTab': 1,
                                                },
                                              ),
                                              child: _CountLabel(
                                                  label: 'following',
                                                  value: followingCount.value),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (currentUser != null &&
                                  currentUser.id != userId) ...[
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    FollowButton(
                                      targetUserId: userId,
                                      serverIsFollowing: isFollowing,
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      onPressed: () => context.push(
                                          '/messages/compose/$userId',
                                          extra: displayName),
                                      icon: const Icon(
                                          Icons.mail_outline_rounded,
                                          size: 16),
                                      label: Text('Message',
                                          style: GoogleFonts.figtree(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      // The app-wide OutlinedButtonTheme sets
                                      // minimumSize: Size(double.infinity, 52)
                                      // (correct for the full-width buttons
                                      // it's designed for). Placed bare in a
                                      // Row, that infinite width has nothing
                                      // to resolve against and crashes layout
                                      // for the whole sliver — hence a blank
                                      // profile screen with no error banner
                                      // (a render-phase failure, not a build
                                      // exception). Override it here so this
                                      // button hugs its content instead.
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 9),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        side: BorderSide(
                                            color: cs.onSurface
                                                .withValues(alpha: 0.25)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 28),
                              Container(
                                  height: 1,
                                  color: cs.outline.withValues(alpha: 0.6)),
                              const SizedBox(height: 20),
                              Text(
                                'POSTS',
                                style: GoogleFonts.figtree(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.35),
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      postsAsync.when(
                        loading: () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                        error: (e, _) =>
                            const SliverToBoxAdapter(child: SizedBox.shrink()),
                        data: (posts) {
                          if (posts.isEmpty) {
                            return SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 16, 24, 40),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  'No posts yet.',
                                  style: GoogleFonts.figtree(
                                    fontSize: 14,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            );
                          }
                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _PostRow(
                                    post: posts[index],
                                    isLast: index == posts.length - 1),
                                childCount: posts.length,
                              ),
                            ),
                          );
                        },
                      ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  final String label;
  final int? value;
  const _CountLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      '${value ?? 0} $label',
      style: GoogleFonts.figtree(
        fontSize: 13,
        color: cs.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 32, color: cs.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  'Try again',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  final CommunityPost post;
  final bool isLast;
  const _PostRow({required this.post, required this.isLast});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}', extra: post),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.6))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _relativeTime(post.createdAt),
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                if (post.situationTag != null) ...[
                  const SizedBox(width: 8),
                  SituationTagChip(situationTag: post.situationTag),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              post.body,
              style: GoogleFonts.figtree(fontSize: 14, color: cs.onSurface, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
