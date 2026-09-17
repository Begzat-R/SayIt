import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../services/auth_service.dart';
import '../../community/widgets/user_actions_menu.dart';
import '../models/message.dart';
import '../models/message_request.dart';
import '../providers/messages_provider.dart';
import '../widgets/edge_swipe_back.dart';

/// Single conversation surface for both an existing thread and a
/// brand-new one. [threadId] is null when opened from a "Message" button
/// with no accepted thread yet (previously a separate compose screen,
/// NewMessageScreen) — this screen resolves whether one already exists,
/// and if not, shows an empty message list with the input ready to go,
/// exactly like an existing thread. Subscribes to `messages` filtered by
/// thread id via postgres_changes once a thread id is known, so both
/// sides see new messages — and read receipts — live.
class ThreadScreen extends ConsumerStatefulWidget {
  final String? threadId;
  final String otherUserId;
  final String otherDisplayName;

  const ThreadScreen({
    super.key,
    this.threadId,
    required this.otherUserId,
    required this.otherDisplayName,
  });

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

enum MessageDeliveryStatus { sending, sent, seen, failed }

/// Unifies a confirmed `Message` row, the single body of a still-pending
/// outgoing `message_requests` row, and a local optimistic `PendingMessage`
/// into one shape the bubble list can render without three separate
/// branches.
class _DisplayMessage {
  final String id;
  final String content;
  final DateTime createdAt;
  final bool isMine;
  final MessageDeliveryStatus? status;
  final String? pendingClientId;

  const _DisplayMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.isMine,
    this.status,
    this.pendingClientId,
  });
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Set<String> _animatedIds = {};
  bool _seededInitialIds = false;
  String? _markedReadThreadId;

  // Captured once, up front, rather than via `ref.read(...)` inside
  // dispose(): in a delayed-unmount (e.g. mid pop-transition), Riverpod's
  // `ref` on this element can already be invalid by the time dispose()
  // runs, even though the notifier object itself (owned by the provider,
  // not the widget) is still perfectly usable.
  late final StateController<String?> _activeConversationCtrl;

  @override
  void initState() {
    super.initState();
    _activeConversationCtrl = ref.read(activeConversationUserIdProvider.notifier);
    if (widget.threadId != null) {
      _markedReadThreadId = widget.threadId;
      markThreadRead(widget.threadId!);
    }
    // So the app-wide new-message banner suppresses itself for whichever
    // conversation is already on screen — see NewMessageBannerOverlay.
    // Deferred a frame: Riverpod forbids modifying a provider during
    // initState (it still counts as "the widget tree is building").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activeConversationCtrl.state = widget.otherUserId;
    });
  }

  @override
  void dispose() {
    // Deferred to a microtask for the same reason as initState above —
    // Riverpod forbids modifying a provider synchronously while a route is
    // being torn down as part of a build pass.
    if (_activeConversationCtrl.state == widget.otherUserId) {
      Future.microtask(() => _activeConversationCtrl.state = null);
    }
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) return;
    _ctrl.clear();
    final pendingNotifier = ref.read(pendingMessagesProvider(widget.otherUserId).notifier);
    final clientId = pendingNotifier.addSending(content);
    _scheduleScrollToBottom();
    await _dispatch(content, pendingNotifier, clientId);
  }

  Future<void> _retry(_DisplayMessage pending) async {
    final pendingNotifier = ref.read(pendingMessagesProvider(widget.otherUserId).notifier);
    pendingNotifier.markSending(pending.pendingClientId!);
    await _dispatch(pending.content, pendingNotifier, pending.pendingClientId!);
  }

  Future<void> _dispatch(
    String content,
    PendingMessagesNotifier pendingNotifier,
    String clientId,
  ) async {
    final result = await ref.read(sendMessageProvider.notifier).send(widget.otherUserId, content);
    if (!mounted) return;
    if (result == null) {
      pendingNotifier.markFailed(clientId);
      return;
    }
    HapticFeedback.lightImpact();
    pendingNotifier.remove(clientId);
    if (result.kind == 'message') {
      if (widget.threadId == null) {
        ref.invalidate(threadIdForUserProvider(widget.otherUserId));
      }
    } else {
      ref.invalidate(pendingOutgoingRequestProvider(widget.otherUserId));
    }
    _scheduleScrollToBottom();
  }

  List<_DisplayMessage> _merge({
    required List<Message> confirmed,
    required List<PendingMessage> pending,
    required MessageRequest? pendingRequest,
    required String? myId,
  }) {
    final items = <_DisplayMessage>[];
    if (pendingRequest != null) {
      items.add(_DisplayMessage(
        id: 'request_${pendingRequest.id}',
        content: pendingRequest.body,
        createdAt: pendingRequest.createdAt,
        isMine: true,
        status: MessageDeliveryStatus.sent,
      ));
    }
    for (final m in confirmed) {
      final isMine = m.senderId == myId;
      items.add(_DisplayMessage(
        id: m.id,
        content: m.content,
        createdAt: m.createdAt,
        isMine: isMine,
        status: isMine
            ? (m.readAt != null ? MessageDeliveryStatus.seen : MessageDeliveryStatus.sent)
            : null,
      ));
    }
    for (final p in pending) {
      items.add(_DisplayMessage(
        id: 'pending_${p.clientId}',
        content: p.content,
        createdAt: p.createdAt,
        isMine: true,
        status: p.status == PendingStatus.failed
            ? MessageDeliveryStatus.failed
            : MessageDeliveryStatus.sending,
        pendingClientId: p.clientId,
      ));
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  bool _shouldAnimate(String id, bool isFirstEmission) {
    if (isFirstEmission) {
      _animatedIds.add(id);
      return false;
    }
    if (_animatedIds.contains(id)) return false;
    _animatedIds.add(id);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    // sendMessageProvider is only ever touched via ref.read (its AsyncValue
    // isn't rendered directly — see pendingLocal for the "sending" state
    // this screen actually shows), so nothing else keeps this autoDispose
    // notifier alive across the send()'s await. Without this watch it gets
    // disposed the instant _dispatch's ref.read call returns, and the
    // in-flight send() throws trying to update state on a disposed notifier.
    ref.watch(sendMessageProvider);

    final resolvedThreadIdAsync = widget.threadId == null
        ? ref.watch(threadIdForUserProvider(widget.otherUserId))
        : null;
    final effectiveThreadId = widget.threadId ?? resolvedThreadIdAsync?.valueOrNull;

    // Mark read the moment a thread resolves (Message-button entry point) —
    // initState only covers the case where threadId was already known.
    if (widget.threadId == null) {
      ref.listen<AsyncValue<String?>>(threadIdForUserProvider(widget.otherUserId), (prev, next) {
        final id = next.valueOrNull;
        if (id != null && id != _markedReadThreadId) {
          _markedReadThreadId = id;
          markThreadRead(id);
        }
      });
    }

    final pendingRequestAsync = effectiveThreadId == null
        ? ref.watch(pendingOutgoingRequestProvider(widget.otherUserId))
        : const AsyncValue<MessageRequest?>.data(null);
    final pendingRequest = pendingRequestAsync.valueOrNull;
    final awaitingAcceptance = effectiveThreadId == null && pendingRequest != null;

    final pendingLocal = ref.watch(pendingMessagesProvider(widget.otherUserId));
    final isSending = pendingLocal.any((p) => p.status == PendingStatus.sending);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: EdgeSwipeBack(
        child: SafeArea(
          child: Column(
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
                        widget.otherDisplayName,
                        style: GoogleFonts.figtree(
                            fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
                      ),
                    ),
                    UserActionsMenu(
                      targetUserId: widget.otherUserId,
                      targetDisplayName: widget.otherDisplayName,
                      onBlocked: () {
                        if (context.canPop()) context.pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: effectiveThreadId != null
                    ? ref.watch(threadMessagesProvider(effectiveThreadId)).when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          error: (e, _) => Center(
                            child: Text('Could not load messages.',
                                style: GoogleFonts.figtree(fontSize: 14)),
                          ),
                          data: (messages) => _buildList(
                            _merge(
                              confirmed: messages,
                              pending: pendingLocal,
                              pendingRequest: null,
                              myId: currentUserId,
                            ),
                          ),
                        )
                    : _buildList(
                        _merge(
                          confirmed: const [],
                          pending: pendingLocal,
                          pendingRequest: pendingRequest,
                          myId: currentUserId,
                        ),
                      ),
              ),
              if (awaitingAcceptance)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Waiting for ${widget.otherDisplayName} to accept your message request.',
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              _MessageInputBar(
                controller: _ctrl,
                isLoading: isSending,
                enabled: !awaitingAcceptance,
                onSubmit: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<_DisplayMessage> messages) {
    final isFirstEmission = !_seededInitialIds;
    if (isFirstEmission) _seededInitialIds = true;

    final items = _buildTimelineItems(messages);
    _scheduleScrollToBottomIfNeeded();

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DateTime) {
          return _DateSeparator(label: _formatDateSeparator(item));
        }
        final entry = item as _TimelineMessage;
        final animate = _shouldAnimate(entry.message.id, isFirstEmission);
        final bubble = _MessageBubble(
          message: entry.message,
          showStatus: entry.isClusterTail,
          onRetry: entry.message.status == MessageDeliveryStatus.failed
              ? () => _retry(entry.message)
              : null,
        );
        if (!animate) return bubble;
        return _EntranceAnimation(child: bubble);
      },
    );
  }

  void _scheduleScrollToBottomIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 80) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }
}

/// Expands a flat, chronological message list into a list of `DateTime`
/// (day markers, truncated to midnight — rendered as a _DateSeparator) and
/// `_TimelineMessage` items, inserting a marker whenever the calendar day
/// changes. `isClusterTail` is true for the last message of a consecutive
/// run by the same sender (or the very last message overall) — only those
/// show a delivery-status indicator, matching WhatsApp/iMessage rather
/// than stamping every single bubble.
class _TimelineMessage {
  final _DisplayMessage message;
  final bool isClusterTail;
  const _TimelineMessage(this.message, this.isClusterTail);
}

List<Object> _buildTimelineItems(List<_DisplayMessage> messages) {
  final items = <Object>[];
  DateTime? lastDay;
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
    if (lastDay == null || day != lastDay) {
      items.add(day);
      lastDay = day;
    }
    final isTail = i == messages.length - 1 || messages[i + 1].isMine != m.isMine;
    items.add(_TimelineMessage(m, isTail));
  }
  return items;
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDateSeparator(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  final label = '${_monthNames[day.month - 1]} ${day.day}';
  return day.year == now.year ? label : '$label, ${day.year}';
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.35),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// One-shot slide-up + fade for a message bubble the very first time it
/// appears in this screen instance — historical messages loaded on open
/// are seeded as already-seen (see _shouldAnimate) so only genuinely new
/// arrivals (realtime or freshly sent) animate in.
class _EntranceAnimation extends StatefulWidget {
  final Widget child;
  const _EntranceAnimation({required this.child});

  @override
  State<_EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<_EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _DisplayMessage message;
  final bool showStatus;
  final VoidCallback? onRetry;
  const _MessageBubble({required this.message, required this.showStatus, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMine = message.isMine;
    final failed = message.status == MessageDeliveryStatus.failed;

    return GestureDetector(
      onTap: failed ? onRetry : null,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: failed
                    ? AppColors.error.withValues(alpha: 0.12)
                    : isMine
                        ? AppColors.primary
                        : cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: failed ? Border.all(color: AppColors.error.withValues(alpha: 0.4)) : null,
              ),
              child: Text(
                message.content,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  height: 1.4,
                  color: failed ? AppColors.error : (isMine ? Colors.white : cs.onSurface),
                ),
              ),
            ),
            if (showStatus && isMine && message.status != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 6),
                child: _StatusIndicator(status: message.status!, cs: cs),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final MessageDeliveryStatus status;
  final ColorScheme cs;
  const _StatusIndicator({required this.status, required this.cs});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return Icon(Icons.access_time_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.3));
      case MessageDeliveryStatus.sent:
        return Icon(Icons.done_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.35));
      case MessageDeliveryStatus.seen:
        return const Icon(Icons.done_all_rounded, size: 14, color: AppColors.primary);
      case MessageDeliveryStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 12, color: AppColors.error),
            const SizedBox(width: 4),
            Text('Failed — tap to retry',
                style: GoogleFonts.figtree(fontSize: 11, color: AppColors.error)),
          ],
        );
    }
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onSubmit;

  const _MessageInputBar({
    required this.controller,
    required this.isLoading,
    required this.enabled,
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
        border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              autofocus: true,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              style: GoogleFonts.figtree(fontSize: 15, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: enabled ? 'Message…' : 'Waiting for reply…',
                hintStyle:
                    GoogleFonts.figtree(fontSize: 15, color: cs.onSurface.withValues(alpha: 0.35)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (isLoading || !enabled) ? null : onSubmit,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: enabled ? AppColors.primary : cs.onSurface.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: enabled ? AppColors.softShadow() : null,
              ),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
