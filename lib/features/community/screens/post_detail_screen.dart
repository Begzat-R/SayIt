import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../services/auth_service.dart';
import '../models/community_post.dart';
import '../models/community_reply.dart';
import '../providers/community_provider.dart';
import '../widgets/initial_avatar.dart';
import '../widgets/situation_tag_chip.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final CommunityPost? initialPost;
  final bool scrollToComments;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.scrollToComments = false,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _commentsKey = GlobalKey();
  bool _pendingScrollToComments = false;

  @override
  void initState() {
    super.initState();
    _pendingScrollToComments = widget.scrollToComments;
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _maybeScrollToComments() {
    if (!_pendingScrollToComments) return;
    _pendingScrollToComments = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _commentsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submit() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    final ok =
        await ref.read(addReplyProvider.notifier).submit(widget.postId, body);
    if (ok && mounted) {
      HapticFeedback.lightImpact();
      _replyCtrl.clear();
      // Scroll to bottom after the reply appears
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Widget _buildPostSection(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    if (widget.initialPost != null) {
      return _PostContent(post: widget.initialPost!, ref: ref);
    }
    // Reached without an in-memory post (e.g. from a notification, which
    // only carries a postId) — fetch it directly rather than rendering
    // nothing for this section.
    final postAsync = ref.watch(postByIdProvider(widget.postId));
    return postAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Could not load this post.',
          style: GoogleFonts.figtree(
              fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4)),
        ),
      ),
      data: (post) {
        if (post == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'This post is unavailable.',
              style: GoogleFonts.figtree(
                  fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          );
        }
        return _PostContent(post: post, ref: ref);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repliesAsync = ref.watch(postRepliesProvider(widget.postId));
    final isSubmitting = ref.watch(addReplyProvider) is AsyncLoading;
    final currentUser = ref.watch(currentUserProvider);
    final post = widget.initialPost ??
        ref.watch(postByIdProvider(widget.postId)).value;
    _maybeScrollToComments();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                children: [
                  _buildPostSection(context, ref),
                  const SizedBox(height: 8),
                  Container(
                    key: _commentsKey,
                    height: 1,
                    color: cs.outline.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 8),
                  repliesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        'Could not load comments.',
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    data: (replies) {
                      if (replies.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            'No comments yet.',
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: replies
                            .asMap()
                            .entries
                            .map((e) => _ReplyRow(
                                  reply: e.value,
                                  isLast: e.key == replies.length - 1,
                                  canDelete: currentUser != null &&
                                      (currentUser.id == e.value.userId ||
                                          currentUser.id == post?.userId),
                                ))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            // Reply input (signed-in users only)
            if (currentUser != null)
              _ReplyInputBar(
                controller: _replyCtrl,
                isLoading: isSubmitting,
                onSubmit: _submit,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Post content (full view) ─────────────────────────────────────────────────

class _PostContent extends StatelessWidget {
  final CommunityPost post;
  final WidgetRef ref;

  const _PostContent({required this.post, required this.ref});

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
    final currentUser = ref.watch(currentUserProvider);
    final likeOverrides = ref.watch(likeNotifierProvider);
    final override = likeOverrides[post.id];
    final isLiked = override?.isLiked ?? post.isLikedByCurrentUser;
    final likeCount = override?.count ?? post.likeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InitialAvatar(name: post.displayName, size: 32),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.displayName,
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  _relativeTime(post.createdAt),
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
            if (post.situationTag != null) ...[
              const SizedBox(width: 8),
              SituationTagChip(situationTag: post.situationTag),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          post.body,
          style: GoogleFonts.figtree(
            fontSize: 16,
            color: cs.onSurface,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 14),
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
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      key: ValueKey(isLiked),
                      size: 18,
                      color: isLiked
                          ? AppColors.like
                          : cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$likeCount',
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      color: isLiked
                          ? AppColors.like
                          : cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 5),
            Text(
              '${post.commentCount}',
              style: GoogleFonts.figtree(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Reply row ────────────────────────────────────────────────────────────────

class _ReplyRow extends ConsumerWidget {
  final CommunityReply reply;
  final bool isLast;
  final bool canDelete;
  const _ReplyRow({
    required this.reply,
    required this.isLast,
    required this.canDelete,
  });

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(deleteCommentProvider.notifier).delete(reply.id);
    if (ok) HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: canDelete ? () => _confirmDelete(context, ref) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: cs.outline.withValues(alpha: 0.5))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(name: reply.displayName, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        reply.displayName,
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('·',
                          style: GoogleFonts.figtree(
                              fontSize: 12,
                              color:
                                  cs.onSurface.withValues(alpha: 0.3))),
                      const SizedBox(width: 6),
                      Text(
                        _relativeTime(reply.createdAt),
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    reply.body,
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      color: cs.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (canDelete)
              GestureDetector(
                onTap: () => _confirmDelete(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Reply input bar ──────────────────────────────────────────────────────────

class _ReplyInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _ReplyInputBar({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 12, 12 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              style: GoogleFonts.figtree(fontSize: 15, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle: GoogleFonts.figtree(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : onSubmit,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: AppColors.softShadow(),
              ),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
