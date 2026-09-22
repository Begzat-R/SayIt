import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../messages/providers/messages_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import 'profile_provider.dart';

final _db = Supabase.instance.client;

/// Whether the current user has blocked [userId]. Only ever reflects
/// blocks *I* created — the blocks SELECT policy doesn't let me see blocks
/// placed against me by someone else (see public.is_blocked in the
/// migration for why that check still works server-side).
final amIBlockingProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, userId) async {
  final me = ref.watch(currentUserProvider)?.id;
  if (me == null) return false;
  final row = await _db
      .from('blocks')
      .select('id')
      .eq('blocker_id', me)
      .eq('blocked_id', userId)
      .maybeSingle();
  return row != null;
});

class BlockNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  BlockNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> setBlocked(String targetUserId, bool blocked) async {
    final me = _db.auth.currentUser?.id;
    if (me == null) return false;
    state = const AsyncValue.loading();
    try {
      if (blocked) {
        await _db.from('blocks').insert({
          'blocker_id': me,
          'blocked_id': targetUserId,
        });
      } else {
        await _db
            .from('blocks')
            .delete()
            .eq('blocker_id', me)
            .eq('blocked_id', targetUserId);
      }
      _ref.invalidate(amIBlockingProvider(targetUserId));
      // Blocking doesn't touch messages/community_posts, so nothing
      // triggers those realtime-subscribed providers to refetch on its
      // own — without this, a thread or profile already loaded in this
      // session would keep showing the blocked user's content until the
      // app restarted, even though the data is genuinely gone server-side.
      _ref.invalidate(threadsProvider);
      _ref.invalidate(incomingRequestsProvider);
      _ref.invalidate(publicProfileProvider(targetUserId));
      _ref.invalidate(userPostsProvider(targetUserId));
      // Same reasoning: a notification whose actor is this user embeds
      // their profile at fetch time. If that fetch happened while blocked,
      // the embed resolved to null and the row is stuck showing "Someone"
      // until something refetches it — do that now instead of waiting for
      // an unrelated new notification to trigger it.
      _ref.invalidate(notificationsProvider);
      // The invalidations above can trigger a rebuild that drops the last
      // widget watching this (autoDispose) notifier before this function
      // resumes — e.g. invalidating publicProfileProvider re-renders the
      // profile screen into its error/unavailable state, which no longer
      // reads blockNotifierProvider. Writing to `state` after that throws
      // "used after dispose". The block/unblock itself already succeeded
      // server-side at this point, so there's nothing left to report to.
      if (mounted) state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final blockNotifierProvider =
    StateNotifierProvider.autoDispose<BlockNotifier, AsyncValue<void>>((ref) {
  return BlockNotifier(ref);
});

class ReportNotifier extends StateNotifier<AsyncValue<void>> {
  ReportNotifier() : super(const AsyncValue.data(null));

  Future<bool> reportUser(String targetUserId, String reason) async {
    final me = _db.auth.currentUser?.id;
    if (me == null || reason.trim().isEmpty) return false;
    state = const AsyncValue.loading();
    try {
      await _db.from('reports').insert({
        'reporter_id': me,
        'target_type': 'user',
        'target_id': targetUserId,
        'reason': reason.trim(),
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final reportNotifierProvider =
    StateNotifierProvider.autoDispose<ReportNotifier, AsyncValue<void>>((ref) {
  return ReportNotifier();
});
