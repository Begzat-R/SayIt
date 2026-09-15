import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../services/auth_service.dart';
import '../models/community_post.dart';
import '../providers/profile_provider.dart';
import '../widgets/initial_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName(String userId) async {
    final saved = await ref
        .read(profileEditProvider.notifier)
        .updateDisplayName(userId, _nameCtrl.text);
    if (saved && mounted) {
      setState(() => _editing = false);
    }
  }

  void _startEditing(String currentName) {
    _nameCtrl.text = currentName;
    setState(() => _editing = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);

    // Pop when user signs out
    ref.listen<dynamic>(currentUserProvider, (_, next) {
      if (next == null && context.canPop()) context.pop();
    });

    if (user == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(myProfileProvider);
    final myPostsAsync = ref.watch(myPostsProvider);
    final editState = ref.watch(profileEditProvider);
    final isSaving = editState is AsyncLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back,
                        size: 22, color: cs.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Could not load profile.',
                      style: GoogleFonts.figtree(fontSize: 14)),
                ),
                data: (profile) {
                  final displayName =
                      profile?['display_name'] as String? ?? '';
                  final effectiveName =
                      displayName.isNotEmpty ? displayName : user.email ?? '?';

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              InitialAvatar(name: effectiveName, size: 56),
                              const SizedBox(height: 20),

                              // Display name + edit
                              if (_editing) ...[
                                TextField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  style: GoogleFonts.figtree(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Your name',
                                    hintStyle: GoogleFonts.figtree(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  onSubmitted: (_) => _saveName(user.id),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 40,
                                      child: ElevatedButton(
                                        onPressed:
                                            isSaving ? null : () => _saveName(user.id),
                                        child: isSaving
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : Text('Save',
                                                style: GoogleFonts.figtree(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _editing = false),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.figtree(
                                          fontSize: 14,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      effectiveName,
                                      style: GoogleFonts.epilogue(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                        letterSpacing: -0.2,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () =>
                                          _startEditing(displayName),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                                if (displayName.isNotEmpty)
                                  Text(
                                    user.email ?? '',
                                    style: GoogleFonts.figtree(
                                      fontSize: 13,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 32),

                              // Sign out
                              GestureDetector(
                                onTap: () => ref
                                    .read(authNotifierProvider.notifier)
                                    .signOut(),
                                child: Text(
                                  'Sign out',
                                  style: GoogleFonts.figtree(
                                    fontSize: 14,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),

                              Container(
                                  height: 1,
                                  color: cs.outline
                                      .withValues(alpha: 0.6)),
                              const SizedBox(height: 20),
                              Text(
                                'YOUR POSTS',
                                style: GoogleFonts.figtree(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.35),
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),

                      // Posts list
                      myPostsAsync.when(
                        loading: () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          ),
                        ),
                        error: (e, _) => const SliverToBoxAdapter(
                            child: SizedBox.shrink()),
                        data: (posts) {
                          if (posts.isEmpty) {
                            return SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                  32, 16, 32, 40),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  "You haven't posted yet.",
                                  style: GoogleFonts.figtree(
                                    fontSize: 14,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            );
                          }
                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _OwnPostRow(
                                  post: posts[index],
                                  isLast: index == posts.length - 1,
                                ),
                                childCount: posts.length,
                              ),
                            ),
                          );
                        },
                      ),
                      const SliverPadding(
                          padding: EdgeInsets.only(bottom: 40)),
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

// ─── Own post row (simplified, no likes) ─────────────────────────────────────

class _OwnPostRow extends StatelessWidget {
  final CommunityPost post;
  final bool isLast;
  const _OwnPostRow({required this.post, required this.isLast});

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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: cs.outline.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _relativeTime(post.createdAt),
            style: GoogleFonts.figtree(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            style: GoogleFonts.figtree(
              fontSize: 14,
              color: cs.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite_outline_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(width: 3),
              Text(
                '${post.likeCount}',
                style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(width: 3),
              Text(
                '${post.commentCount}',
                style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
