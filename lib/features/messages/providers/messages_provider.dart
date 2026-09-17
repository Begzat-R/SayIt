import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../services/auth_service.dart';
import '../models/message.dart';
import '../models/message_request.dart';
import '../models/thread_summary.dart';

final _db = Supabase.instance.client;
const _uuid = Uuid();

/// The other-party user id of whichever conversation (thread or brand-new
/// compose) is currently on screen. Set/cleared by ThreadScreen so the
/// new-message banner (shown everywhere else in the app) can suppress
/// itself for the conversation the user is already looking at — that case
/// is instead handled by the in-thread slide-up animation.
final activeConversationUserIdProvider = StateProvider<String?>((ref) => null);

// ─── Incoming requests ────────────────────────────────────────────────────────

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<MessageRequest>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final rows = await _db
      .from('message_requests')
      .select(
        'id, sender_id, receiver_id, body, status, created_at, '
        'sender:profiles!message_requests_sender_id_fkey(display_name)',
      )
      .eq('receiver_id', user.id)
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  return (rows as List)
      .map((r) => MessageRequest.fromJson(r as Map<String, dynamic>))
      .toList();
});

class RequestActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  RequestActionNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Returns the new thread id on success, so the caller can navigate
  /// straight into the conversation.
  Future<String?> accept(String requestId) async {
    state = const AsyncValue.loading();
    try {
      final threadId = await _db.rpc(
        'accept_message_request',
        params: {'p_request_id': requestId},
      ) as String;
      _ref.invalidate(incomingRequestsProvider);
      _ref.invalidate(threadsProvider);
      state = const AsyncValue.data(null);
      return threadId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> decline(String requestId) async {
    state = const AsyncValue.loading();
    try {
      await _db.rpc('decline_message_request', params: {'p_request_id': requestId});
      _ref.invalidate(incomingRequestsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final requestActionProvider =
    StateNotifierProvider.autoDispose<RequestActionNotifier, AsyncValue<void>>(
        (ref) {
  return RequestActionNotifier(ref);
});

/// Whether the current user already has a pending outgoing request to
/// [otherUserId] with no thread yet — lets the unified ThreadScreen show
/// "waiting for them to accept" instead of a second input box, matching
/// what the Requests tab already enforces server-side (only one pending
/// request per direction; see public.send_direct_message).
final pendingOutgoingRequestProvider =
    FutureProvider.autoDispose.family<MessageRequest?, String>((ref, otherUserId) async {
  final me = ref.watch(currentUserProvider)?.id;
  if (me == null) return null;
  final row = await _db
      .from('message_requests')
      .select(
        'id, sender_id, receiver_id, body, status, created_at, '
        'sender:profiles!message_requests_sender_id_fkey(display_name)',
      )
      .eq('sender_id', me)
      .eq('receiver_id', otherUserId)
      .eq('status', 'pending')
      .maybeSingle();
  return row == null ? null : MessageRequest.fromJson(row);
});

/// Id of the already-accepted thread with [otherUserId], if one exists.
/// Lets ThreadScreen resolve straight to a real conversation when opened
/// from a "Message" button rather than the Chats list (which already
/// knows the thread id).
final threadIdForUserProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, otherUserId) async {
  final me = ref.watch(currentUserProvider)?.id;
  if (me == null) return null;
  final a = me.compareTo(otherUserId) < 0 ? me : otherUserId;
  final b = me.compareTo(otherUserId) < 0 ? otherUserId : me;
  final row = await _db
      .from('threads')
      .select('id')
      .eq('user_a', a)
      .eq('user_b', b)
      .maybeSingle();
  return row?['id'] as String?;
});

// ─── Threads (accepted conversations) ─────────────────────────────────────────

Future<List<ThreadSummary>> _fetchThreadPreviews() async {
  final rows = await _db
      .from('thread_previews')
      .select(
        'thread_id, other_user_id, other_display_name, '
        'last_message, last_message_at, unread_count',
      )
      .order('last_message_at', ascending: false);
  return (rows as List)
      .map((r) => ThreadSummary.fromJson(r as Map<String, dynamic>))
      .toList();
}

/// A message just arrived from someone else, on a thread the recipient
/// isn't currently viewing — carries what the app-wide banner needs to
/// render and to navigate through on tap. See incomingMessageEventsProvider.
class IncomingMessageEvent {
  final String threadId;
  final String otherUserId;
  final String otherDisplayName;
  final String preview;
  const IncomingMessageEvent({
    required this.threadId,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.preview,
  });
}

/// Singleton (module-level, not per-provider-instance) so it survives
/// threadsProvider being disposed/recreated and always has exactly one
/// producer — threadsProvider's own realtime channel below forwards into
/// it rather than a second subscription being opened just for the banner.
final _incomingMessageEvents = StreamController<IncomingMessageEvent>.broadcast();

/// Watched by the app-wide banner overlay (see NewMessageBannerOverlay).
/// Carries no history — only events observed while something is watching
/// this provider (which is always true once the overlay is mounted, i.e.
/// for the app's whole signed-in lifetime).
final incomingMessageEventsProvider =
    StreamProvider.autoDispose<IncomingMessageEvent>((ref) => _incomingMessageEvents.stream);

/// Same fetch-then-refetch-on-postgres_changes shape as notificationsProvider
/// and threadMessagesProvider. Subscribes to all of `messages` (unfiltered —
/// a single equality filter can't express "thread_id in (my threads)"),
/// mirroring the same broad-then-refetch tradeoff communityPostsProvider
/// already makes for community_posts. unreadThreadCountProvider derives
/// from this rather than opening its own channel; so does the banner above.
final threadsProvider =
    StreamProvider.autoDispose<List<ThreadSummary>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  final controller = StreamController<List<ThreadSummary>>();

  if (userId == null) {
    controller.add(const []);
    controller.close();
    return controller.stream;
  }

  // Cached purely so an incoming-message INSERT payload (sender_id +
  // thread_id only) can be resolved to a display name for the banner
  // without a second round trip — best-effort; a miss just falls back to
  // a generic label until the next fetchAndEmit corrects it.
  var lastSnapshot = <String, ThreadSummary>{};

  void fetchAndEmit() {
    _fetchThreadPreviews().then((list) {
      lastSnapshot = {for (final t in list) t.threadId: t};
      controller.add(list);
    }).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });
  }

  fetchAndEmit();

  final channel = _db
      .channel('thread_previews_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          fetchAndEmit();
          final row = payload.newRecord;
          final senderId = row['sender_id'] as String?;
          final threadId = row['thread_id'] as String?;
          if (senderId == null || senderId == userId || threadId == null) return;
          final cached = lastSnapshot[threadId];
          final otherUserId = cached?.otherUserId ?? senderId;
          // Suppress the banner for whichever conversation is already on
          // screen — ThreadScreen's own realtime subscription handles that
          // case with an in-place slide-up animation instead.
          if (ref.read(activeConversationUserIdProvider) == otherUserId) return;
          _incomingMessageEvents.add(IncomingMessageEvent(
            threadId: threadId,
            otherUserId: otherUserId,
            otherDisplayName: cached?.otherDisplayName ?? 'Someone',
            preview: row['content'] as String? ?? '',
          ));
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (_) => fetchAndEmit(),
      )
      .subscribe();

  ref.onDispose(() {
    _db.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

/// Number of threads with at least one unread message (the conventional
/// "unread chats" badge — Instagram/WhatsApp count conversations, not
/// total unread messages). Derived from threadsProvider's already-live
/// stream, same pattern as unreadNotificationCountProvider.
final unreadThreadCountProvider = Provider.autoDispose<int>((ref) {
  final threads = ref.watch(threadsProvider).value ?? const [];
  return threads.where((t) => t.hasUnread).length;
});

// ─── Messages within a thread (realtime) ──────────────────────────────────────

Future<List<Message>> _fetchMessages(String threadId) async {
  final rows = await _db
      .from('messages')
      .select('id, thread_id, sender_id, content, created_at, read_at')
      .eq('thread_id', threadId)
      .order('created_at', ascending: true);
  return (rows as List)
      .map((r) => Message.fromJson(r as Map<String, dynamic>))
      .toList();
}

final threadMessagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, threadId) {
  final controller = StreamController<List<Message>>();

  void fetchAndEmit() {
    _fetchMessages(threadId).then(controller.add).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });
  }

  fetchAndEmit();

  final channel = _db
      .channel('messages_thread_$threadId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'thread_id',
          value: threadId,
        ),
        callback: (_) => fetchAndEmit(),
      )
      .subscribe();

  ref.onDispose(() {
    _db.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ─── Send / mark read ─────────────────────────────────────────────────────────

/// 'message' means it landed straight into an existing thread (threadId
/// set); 'request' means no thread existed yet, so it became a pending
/// message_requests row instead (see public.send_direct_message).
class SendMessageResult {
  final String kind;
  final String? threadId;
  const SendMessageResult({required this.kind, this.threadId});
}

class SendMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  SendMessageNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<SendMessageResult?> send(String receiverId, String content) async {
    if (content.trim().isEmpty) return null;
    state = const AsyncValue.loading();
    try {
      final result = await _db.rpc(
        'send_direct_message',
        params: {'p_receiver_id': receiverId, 'p_content': content.trim()},
      ) as Map<String, dynamic>;
      _ref.invalidate(threadsProvider);
      state = const AsyncValue.data(null);
      return SendMessageResult(
        kind: result['kind'] as String,
        threadId: result['thread_id'] as String?,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final sendMessageProvider =
    StateNotifierProvider.autoDispose<SendMessageNotifier, AsyncValue<void>>(
        (ref) {
  return SendMessageNotifier(ref);
});

// ─── Pending (optimistic, in-flight) outgoing messages ─────────────────────────

enum PendingStatus { sending, failed }

/// A message the current user just sent, shown immediately in ThreadScreen
/// before the server confirms it — keyed by [otherUserId] rather than
/// thread id so it also covers the brand-new-conversation case where no
/// thread exists yet.
class PendingMessage {
  final String clientId;
  final String content;
  final DateTime createdAt;
  final PendingStatus status;

  const PendingMessage({
    required this.clientId,
    required this.content,
    required this.createdAt,
    required this.status,
  });

  PendingMessage copyWith({PendingStatus? status}) => PendingMessage(
        clientId: clientId,
        content: content,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}

class PendingMessagesNotifier extends StateNotifier<List<PendingMessage>> {
  PendingMessagesNotifier() : super(const []);

  String addSending(String content) {
    final clientId = _uuid.v4();
    state = [
      ...state,
      PendingMessage(
        clientId: clientId,
        content: content,
        createdAt: DateTime.now(),
        status: PendingStatus.sending,
      ),
    ];
    return clientId;
  }

  void markFailed(String clientId) {
    state = [
      for (final m in state)
        if (m.clientId == clientId) m.copyWith(status: PendingStatus.failed) else m,
    ];
  }

  void markSending(String clientId) {
    state = [
      for (final m in state)
        if (m.clientId == clientId) m.copyWith(status: PendingStatus.sending) else m,
    ];
  }

  /// Confirmed by the server (either landed in `messages` or became a
  /// `message_requests` row) — the authoritative list/provider now carries
  /// it, so drop the local placeholder.
  void remove(String clientId) {
    state = state.where((m) => m.clientId != clientId).toList();
  }
}

final pendingMessagesProvider = StateNotifierProvider.autoDispose
    .family<PendingMessagesNotifier, List<PendingMessage>, String>((ref, otherUserId) {
  return PendingMessagesNotifier();
});

Future<void> markThreadRead(String threadId) async {
  final user = _db.auth.currentUser;
  if (user == null) return;
  await _db
      .from('messages')
      .update({'read_at': DateTime.now().toIso8601String()})
      .eq('thread_id', threadId)
      .neq('sender_id', user.id)
      .isFilter('read_at', null);
}
