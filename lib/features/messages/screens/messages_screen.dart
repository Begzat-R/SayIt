import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../community/widgets/initial_avatar.dart';
import '../models/message_request.dart';
import '../models/thread_summary.dart';
import '../providers/messages_provider.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pendingCount = ref.watch(incomingRequestsProvider).value?.length ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back, size: 22, color: cs.onSurface),
                      ),
                    ),
                    Text(
                      'Messages',
                      style: GoogleFonts.epilogue(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TabBar(
                  tabs: [
                    const Tab(text: 'Chats'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Requests'),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 6),
                            _CountPill(count: pendingCount),
                          ],
                        ],
                      ),
                    ),
                  ],
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
              const Expanded(
                child: TabBarView(children: [_ChatsTab(), _RequestsTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded count badge used on the Requests tab label.
class _CountPill extends StatelessWidget {
  final int count;
  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: const BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: GoogleFonts.figtree(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: cs.onSurface.withValues(alpha: 0.18)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.35),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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
        ),
      ),
    );
  }
}

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays == 1) return '1d';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(threadsProvider);

    return threadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _ErrorState(
        message: 'Could not load chats.\n${e.toString()}',
        onRetry: () => ref.invalidate(threadsProvider),
      ),
      data: (threads) {
        if (threads.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            subtitle: 'Follow someone and say hello —\nit starts as a request until they accept.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: threads.length,
          itemBuilder: (context, index) {
            final t = threads[index];
            return _ThreadRow(thread: t, relativeTime: _relativeTime(t.lastMessageAt));
          },
        );
      },
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final ThreadSummary thread;
  final String relativeTime;
  const _ThreadRow({required this.thread, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = thread.hasUnread;
    return GestureDetector(
      onTap: () => context.push(
        '/messages/thread/${thread.threadId}',
        extra: {'otherUserId': thread.otherUserId, 'otherDisplayName': thread.otherDisplayName},
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            InitialAvatar(name: thread.otherDisplayName, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.otherDisplayName,
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (thread.lastMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      thread.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                        color: unread
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (relativeTime.isNotEmpty)
                  Text(
                    relativeTime,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                      color: unread
                          ? AppColors.primary
                          : cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                if (unread) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _ErrorState(
        message: 'Could not load requests.\n${e.toString()}',
        onRetry: () => ref.invalidate(incomingRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No message requests',
            subtitle: 'New requests from people you don\'t\nfollow back yet will show up here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: requests.length,
          itemBuilder: (context, index) => _RequestRow(request: requests[index]),
        );
      },
    );
  }
}

class _RequestRow extends ConsumerWidget {
  final MessageRequest request;
  const _RequestRow({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final actionState = ref.watch(requestActionProvider);
    final isLoading = actionState is AsyncLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(name: request.senderDisplayName, size: 32),
              const SizedBox(width: 10),
              Text(
                request.senderDisplayName,
                style: GoogleFonts.figtree(
                    fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.body,
            style: GoogleFonts.figtree(fontSize: 14, color: cs.onSurface, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final threadId = await ref
                            .read(requestActionProvider.notifier)
                            .accept(request.id);
                        if (threadId != null && context.mounted) {
                          context.push('/messages/thread/$threadId', extra: {
                            'otherUserId': request.senderId,
                            'otherDisplayName': request.senderDisplayName,
                          });
                        }
                      },
                // The app-wide ElevatedButtonTheme sets
                // minimumSize: Size(double.infinity, 52) — fine for the
                // full-width buttons it's designed for, but bare in a Row
                // (as here, next to the Decline button) that infinite
                // width has nothing to resolve against. This is the same
                // crash class documented on the profile screen's Message
                // button: a render-phase failure with no on-screen error,
                // so the whole row silently fails to lay out.
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Accept',
                    style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => ref.read(requestActionProvider.notifier).decline(request.id),
                child: Text('Decline',
                    style: GoogleFonts.figtree(
                        fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
