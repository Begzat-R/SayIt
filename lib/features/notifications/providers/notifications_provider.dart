import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../models/app_notification.dart';

final _db = Supabase.instance.client;

Future<List<AppNotification>> _fetchNotifications(String userId) async {
  final rows = await _db
      .from('notifications')
      .select(
        'id, recipient_id, actor_id, type, entity_id, read_at, created_at, '
        'actor:profiles!notifications_actor_id_fkey(display_name)',
      )
      .eq('recipient_id', userId)
      .order('created_at', ascending: false)
      .limit(50);
  return (rows as List)
      .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
      .toList();
}

/// Same shape as threadMessagesProvider: fetch-then-refetch-on-change via
/// postgres_changes, rather than trying to patch individual rows in from
/// realtime payloads (which would need a second query anyway to embed the
/// actor's display_name).
final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  final controller = StreamController<List<AppNotification>>();

  if (userId == null) {
    controller.add(const []);
    controller.close();
    return controller.stream;
  }

  void fetchAndEmit() {
    _fetchNotifications(userId).then(controller.add).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });
  }

  fetchAndEmit();

  final channel = _db
      .channel('notifications_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: userId,
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

/// Derived from notificationsProvider rather than holding its own
/// postgres_changes channel — that provider is already realtime-subscribed
/// and filtered to this user, so a second subscription here would just be
/// a duplicate channel doing the same job. Still fully live: any insert/
/// update on notifications refetches the list, which recomputes this.
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? const [];
  return notifications.where((n) => !n.isRead).length;
});

class MarkReadNotifier extends StateNotifier<AsyncValue<void>> {
  MarkReadNotifier() : super(const AsyncValue.data(null));

  Future<void> markRead(String notificationId) async {
    try {
      await _db
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (_) {
      // Non-critical — worst case the dot stays lit until next markAllRead.
    }
  }

  Future<bool> markAllRead() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return false;
    state = const AsyncValue.loading();
    try {
      await _db
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('recipient_id', userId)
          .isFilter('read_at', null);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final markReadProvider =
    StateNotifierProvider.autoDispose<MarkReadNotifier, AsyncValue<void>>((ref) {
  return MarkReadNotifier();
});
