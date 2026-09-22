import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../services/auth_service.dart';
import '../../messages/providers/messages_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/initial_avatar.dart';
import '../widgets/pill_tab_bar.dart';
import '../widgets/situation_tag_chip.dart';
import '../widgets/suggested_people_row.dart';

// ─────────────────────────────────────────────────────────────────────────────

enum _AuthMode { signIn, signUp }

enum _FeedSort { trending, newest }

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (_mode == _AuthMode.signIn) {
      await ref.read(authNotifierProvider.notifier).signIn(email, password);
    } else {
      await ref.read(authNotifierProvider.notifier).signUp(email, password);
    }
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
      _passwordCtrl.clear();
      _obscure = true;
    });
    ref.read(authNotifierProvider.notifier).clearErrors();
  }

  void _showNewPostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _NewPostSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;

    if (user != null) {
      return _buildFeed(context, cs, user);
    }

    final authState = ref.watch(authNotifierProvider);
    return _buildAuthWall(context, cs, authState);
  }

  // ─── Signed-in feed ────────────────────────────────────────────────────────

  Widget _buildFeed(BuildContext context, ColorScheme cs, dynamic user) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        floatingActionButton: FloatingActionButton(
          onPressed: _showNewPostSheet,
          backgroundColor: AppColors.primary,
          elevation: 3,
          child: const Icon(Icons.add, color: Colors.white, size: 22),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Community',
                        style: GoogleFonts.epilogue(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.search,
                    onTap: () => context.push('/community/search'),
                  ),
                  const SizedBox(width: 10),
                  CircleIconButton(
                    icon: Icons.mail_outline_rounded,
                    onTap: () => context.push('/messages'),
                    showBadge: ref.watch(unreadThreadCountProvider) > 0,
                  ),
                  const SizedBox(width: 10),
                  CircleIconButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: () => context.push('/notifications'),
                    showBadge: ref.watch(unreadNotificationCountProvider) > 0,
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.go('/settings'),
                    child:
                        InitialAvatar(name: user.email ?? '?', size: 30),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: PillTabBar(labels: ['Trending', 'Following', 'New']),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () => context.push('/community/daily-post'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What did you try today?',
                              style: GoogleFonts.figtree(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Share a moment, tag the situation.',
                              style: GoogleFonts.figtree(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _PostsFeed(sort: _FeedSort.trending),
                  const _FollowingFeed(),
                  _PostsFeed(sort: _FeedSort.newest),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Auth wall ─────────────────────────────────────────────────────────────

  Widget _buildAuthWall(
      BuildContext context, ColorScheme cs, AuthFormState authState) {
    final isSignIn = _mode == _AuthMode.signIn;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Text(
              'Community',
              style: GoogleFonts.epilogue(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 36),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSignIn
                          ? 'Sign in to read and share with others who stutter.'
                          : 'Create an account to join the community.',
                      style: GoogleFonts.figtree(
                        fontSize: 15,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style:
                          GoogleFonts.figtree(fontSize: 16, color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        labelStyle: GoogleFonts.figtree(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                        errorText: authState.emailError,
                        errorStyle: GoogleFonts.figtree(
                            fontSize: 12, color: AppColors.error),
                      ),
                      onChanged: (_) =>
                          ref.read(authNotifierProvider.notifier).clearErrors(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      autocorrect: false,
                      style:
                          GoogleFonts.figtree(fontSize: 16, color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: GoogleFonts.figtree(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                        errorText: authState.passwordError,
                        errorStyle: GoogleFonts.figtree(
                            fontSize: 12, color: AppColors.error),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!authState.isLoading) _submit();
                      },
                      onChanged: (_) =>
                          ref.read(authNotifierProvider.notifier).clearErrors(),
                    ),
                    if (authState.generalError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        authState.generalError!,
                        style: GoogleFonts.figtree(
                            fontSize: 13, color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _submit,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isSignIn ? 'Sign in' : 'Create account',
                              style: GoogleFonts.figtree(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: authState.isLoading ? null : _toggleMode,
                        child: Text(
                          isSignIn
                              ? "Don't have an account? Create one"
                              : 'Already have an account? Sign in',
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                              height: 1,
                              color: cs.outline.withValues(alpha: 0.4)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: GoogleFonts.figtree(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                              height: 1,
                              color: cs.outline.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed:
                          authState.isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: cs.onSurface.withValues(alpha: 0.25)),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        foregroundColor: cs.onSurface,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(18, 18),
                            painter: const _GoogleGPainter(),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Continue with Google',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.figtree(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Google G logo painter ────────────────────────────────────────────────────

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFDB4437);
  static const _yellow = Color(0xFFF4B400);
  static const _green = Color(0xFF0F9D58);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final strokeW = size.width * 0.32;
    final r = cx - strokeW / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    void arc(Color c, double startDeg, double sweepDeg) {
      canvas.drawArc(
        rect,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(_blue, 30, 185);
    arc(_green, 215, 50);
    arc(_yellow, 265, 50);
    arc(_red, 315, 15);

    canvas.drawRect(
      Rect.fromLTRB(cx, cy - strokeW / 2, cx + r, cy + strokeW / 2),
      Paint()
        ..color = _blue
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Feed with sort ───────────────────────────────────────────────────────────

class _PostsFeed extends ConsumerWidget {
  final _FeedSort sort;
  const _PostsFeed({required this.sort});

  List<CommunityPost> _applySort(List<CommunityPost> posts) {
    if (sort == _FeedSort.trending) {
      final copy = List<CommunityPost>.from(posts)
        ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
      return copy;
    }
    return posts;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider);
    final cs = Theme.of(context).colorScheme;

    return postsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        itemCount: 4,
        itemBuilder: (context, _) => const _PostCardSkeleton(),
      ),
      error: (e, _) => Center(
        child: Text(
          'Could not load posts.',
          style: GoogleFonts.figtree(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
      data: (posts) {
        final sorted = _applySort(posts);
        // Trending only, not New: shown once per visit to the feed rather
        // than duplicated across both post-sort tabs, and Trending is the
        // default tab (see PillTabBar labels order above) so it's the one
        // every user — including a brand-new one with zero follows and
        // nothing in Following — actually lands on first.
        final showSuggestions = sort == _FeedSort.trending;
        if (sorted.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            children: [
              if (showSuggestions) const SuggestedPeopleRow(),
              Text(
                'No posts yet. Be the first.',
                style: GoogleFonts.figtree(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          // 140 (up from 100) so the compose FAB clears the last card's
          // text once the feed has enough posts to actually scroll near
          // its end — the realistic case for an active feed. Note this
          // padding is inert for a very short feed that doesn't fill the
          // viewport (nothing to scroll means it never gets "used"), so a
          // near-empty feed can still show the same overlap; fixing that
          // edge case too would need the FAB or cards to react to content
          // height, which felt like overkill for a handful of seed posts.
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
          itemCount: sorted.length + (showSuggestions ? 1 : 0),
          itemBuilder: (context, index) {
            if (showSuggestions) {
              if (index == 0) return const SuggestedPeopleRow();
              return _PostCard(post: sorted[index - 1]);
            }
            return _PostCard(post: sorted[index]);
          },
        );
      },
    );
  }
}

// ─── Following feed ───────────────────────────────────────────────────────────

class _FollowingFeed extends ConsumerWidget {
  const _FollowingFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final postsAsync = ref.watch(followingFeedProvider);

    return postsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        itemCount: 3,
        itemBuilder: (context, _) => const _PostCardSkeleton(),
      ),
      error: (e, _) => Center(
        child: Text(
          'Could not load your following feed.',
          style: GoogleFonts.figtree(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 36,
                    color: cs.onSurface.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Follow others to see their posts here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.35),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
          itemCount: posts.length,
          itemBuilder: (context, index) => _PostCard(post: posts[index]),
        );
      },
    );
  }
}

// ─── Post card ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final likeOverrides = ref.watch(likeNotifierProvider);
    final override = likeOverrides[post.id];
    final isLiked = override?.isLiked ?? post.isLikedByCurrentUser;
    final likeCount = override?.count ?? post.likeCount;

    return GestureDetector(
      onTap: () => context.push('/post/${post.id}', extra: post),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            GestureDetector(
              onTap: () => context.push('/community/user/${post.userId}'),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  InitialAvatar(name: post.displayName, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          _relativeTime(post.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.situationTag != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: SituationTagChip(situationTag: post.situationTag),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Content
            Text(
              post.body,
              style: GoogleFonts.figtree(
                fontSize: 15,
                color: cs.onSurface,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 12),
            // Divider
            Container(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            const SizedBox(height: 12),
            // Engagement row
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: currentUser == null
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          ref.read(likeNotifierProvider.notifier).toggle(
                                postId: post.id,
                                currentIsLiked: isLiked,
                                currentCount: likeCount,
                                userId: currentUser.id,
                              );
                        },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? AppColors.like.withValues(alpha: 0.12)
                          : cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_outline_rounded,
                            key: ValueKey(isLiked),
                            size: 15,
                            color: isLiked
                                ? AppColors.like
                                : cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$likeCount',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLiked
                                ? AppColors.like
                                : cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(
                    '/post/${post.id}?scrollToComments=true',
                    extra: post,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${post.commentCount}',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card skeleton ────────────────────────────────────────────────────────────

class _PostCardSkeleton extends StatefulWidget {
  const _PostCardSkeleton();

  @override
  State<_PostCardSkeleton> createState() => _PostCardSkeletonState();
}

class _PostCardSkeletonState extends State<_PostCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final opacity = 0.04 + _anim.value * 0.06;
        final shimmer = cs.onSurface.withValues(alpha: opacity);
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: shimmer, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 100,
                  height: 11,
                  decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ]),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 11,
                decoration: BoxDecoration(
                    color: shimmer, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 6),
              Container(
                width: 200,
                height: 11,
                decoration: BoxDecoration(
                    color: shimmer, borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── New post sheet ───────────────────────────────────────────────────────────

class _NewPostSheet extends ConsumerStatefulWidget {
  const _NewPostSheet();

  @override
  ConsumerState<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends ConsumerState<_NewPostSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    final ok = await ref.read(newPostProvider.notifier).submit(body);
    if (ok && mounted) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = ref.watch(newPostProvider) is AsyncLoading;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(32, 28, 32, 28 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'New post',
                style: GoogleFonts.epilogue(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close,
                    size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'How are you feeling today?',
            style: GoogleFonts.figtree(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLength: 1000,
            maxLines: 5,
            minLines: 3,
            autofocus: true,
            style:
                GoogleFonts.figtree(fontSize: 15, color: cs.onSurface, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Share something with the community…',
              hintStyle: GoogleFonts.figtree(
                  fontSize: 15, color: cs.onSurface.withValues(alpha: 0.35)),
              counterStyle: GoogleFonts.figtree(
                  fontSize: 11, color: cs.onSurface.withValues(alpha: 0.3)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Post',
                    style: GoogleFonts.figtree(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
