import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app.dart' show appRouter;
import '../../../core/theme/colors.dart';
import '../providers/messages_provider.dart';

/// Wraps the entire app (installed via `MaterialApp.router`'s `builder`) so
/// an incoming-message banner can show over *any* screen. Most pushed
/// routes (post detail, a profile, settings) live outside the bottom-tab
/// shell, so a listener placed inside one screen wouldn't fire while
/// looking at another — this sits above the Navigator instead.
class NewMessageBannerOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const NewMessageBannerOverlay({super.key, required this.child});

  @override
  ConsumerState<NewMessageBannerOverlay> createState() => _NewMessageBannerOverlayState();
}

class _NewMessageBannerOverlayState extends ConsumerState<NewMessageBannerOverlay> {
  IncomingMessageEvent? _event;
  Timer? _dismissTimer;

  void _show(IncomingMessageEvent event) {
    _dismissTimer?.cancel();
    setState(() => _event = event);
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (mounted) setState(() => _event = null);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The return value is unused — watching it here just keeps
    // threadsProvider's single realtime channel (which incoming-message
    // events piggyback on) alive for the app's whole signed-in lifetime,
    // including on screens that never touch messaging directly.
    ref.watch(threadsProvider);
    ref.listen<AsyncValue<IncomingMessageEvent>>(incomingMessageEventsProvider, (prev, next) {
      final event = next.valueOrNull;
      if (event != null) _show(event);
    });

    final top = MediaQuery.of(context).padding.top;
    final event = _event;
    return Stack(
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          top: event != null ? top + 8 : top - 120,
          left: 16,
          right: 16,
          child: event == null
              ? const SizedBox.shrink()
              : _BannerCard(
                  event: event,
                  onTap: () {
                    _dismiss();
                    // context here is an ancestor of GoRouter's Navigator
                    // (MaterialApp.router's `builder` context sits above
                    // the Router), so context.push can't resolve it —
                    // appRouter is the same static handle already used for
                    // notification-tap navigation, for the same reason.
                    appRouter?.push('/messages/thread/${event.threadId}', extra: {
                      'otherUserId': event.otherUserId,
                      'otherDisplayName': event.otherDisplayName,
                    });
                  },
                  onDismiss: _dismiss,
                ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final IncomingMessageEvent event;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _BannerCard({required this.event, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -200) onDismiss();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow(),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'New message from ${event.otherDisplayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      if (event.preview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                              fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
