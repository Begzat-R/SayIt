import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../community/widgets/initial_avatar.dart';
import '../models/app_notification.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notificationsAsync = ref.watch(notificationsProvider);
    final markAllState = ref.watch(markReadProvider);
    final isMarkingAll = markAllState is AsyncLoading;

    // Header lives outside notificationsAsync.when(...) so back navigation
    // and "mark all read" are always reachable, regardless of whether the
    // list is loading, errored, or empty — the same lesson as the blank
    // profile-screen bug: a loading/error state must never render as a
    // bare, header-less screen.
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
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
              'Notifications',
              style: GoogleFonts.epilogue(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          if (isMarkingAll)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            GestureDetector(
              onTap: () => ref.read(markReadProvider.notifier).markAllRead(),
              child: Text(
                'Mark all read',
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
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
            const SizedBox(height: 8),
            Expanded(
              child: notificationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => _ErrorState(
                  message: 'Could not load notifications.\n${e.toString()}',
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications yet.',
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Container(
                      height: 1,
                      color: cs.outline.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, i) =>
                        _NotificationRow(notification: items[i]),
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

class _NotificationRow extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationRow({required this.notification});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  /// New notification types can appear before the app is updated to know
  /// about them (the schema has no enum to keep them in sync) — the
  /// default branch keeps that case from rendering something broken.
  String get _message {
    switch (notification.type) {
      case 'follow':
        return '${notification.actorDisplayName} followed you';
      case 'message_request_accepted':
        return '${notification.actorDisplayName} accepted your message request';
      case 'like':
        return '${notification.actorDisplayName} liked your post';
      case 'comment':
        return '${notification.actorDisplayName} commented on your post';
      default:
        return '${notification.actorDisplayName} sent you a notification';
    }
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    if (!notification.isRead) {
      ref.read(markReadProvider.notifier).markRead(notification.id);
    }
    switch (notification.type) {
      case 'follow':
        if (notification.actorId != null) {
          context.push('/community/user/${notification.actorId}');
        }
        break;
      case 'message_request_accepted':
        if (notification.entityId != null) {
          context.push('/messages/thread/${notification.entityId}', extra: {
            'otherUserId': notification.actorId ?? '',
            'otherDisplayName': notification.actorDisplayName,
          });
        }
        break;
      case 'like':
        if (notification.entityId != null) {
          // No in-memory CommunityPost to pass as `extra` here — the post
          // detail screen fetches it by id itself (postByIdProvider).
          context.push('/post/${notification.entityId}');
        }
        break;
      case 'comment':
        if (notification.entityId != null) {
          context.push('/post/${notification.entityId}?scrollToComments=true');
        }
        break;
      default:
        // Unknown type: just mark read, nowhere defined to navigate yet.
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _handleTap(context, ref);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : AppColors.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(name: notification.actorDisplayName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _message,
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight:
                          notification.isRead ? FontWeight.w400 : FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
