import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../models/profile_summary.dart';

final _db = Supabase.instance.client;

/// Ids of every profile the current user follows. Powers the "Following"
/// tab and the filled/outlined state of Follow buttons.
final followingIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  final rows = await _db
      .from('follows')
      .select('following_id')
      .eq('follower_id', user.id);
  return (rows as List).map((r) => r['following_id'] as String).toSet();
});

final followerCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final count = await _db
      .from('follows')
      .count(CountOption.exact)
      .eq('following_id', userId);
  return count;
});

final followingCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final count = await _db
      .from('follows')
      .count(CountOption.exact)
      .eq('follower_id', userId);
  return count;
});

/// Profiles of everyone following [userId] — powers the Followers tab of
/// FollowListScreen. RLS on `profiles`/`follows` already scopes this to
/// non-blocked relationships, so no client-side filtering is needed here.
final followersListProvider =
    FutureProvider.autoDispose.family<List<ProfileSummary>, String>((ref, userId) async {
  final rows = await _db
      .from('follows')
      .select('follower:profiles!follows_follower_id_fkey(id, display_name)')
      .eq('following_id', userId);
  // The profiles embed comes back null (not omitted) for a blocked
  // relationship — profiles RLS hides the row but the follows row itself
  // is still visible, so skip nulls rather than crash on the cast.
  return (rows as List)
      .map((r) => r['follower'] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .map(ProfileSummary.fromJson)
      .toList();
});

/// Profiles of everyone [userId] follows — powers the Following tab.
final followingListProvider =
    FutureProvider.autoDispose.family<List<ProfileSummary>, String>((ref, userId) async {
  final rows = await _db
      .from('follows')
      .select('followed:profiles!follows_following_id_fkey(id, display_name)')
      .eq('follower_id', userId);
  return (rows as List)
      .map((r) => r['followed'] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .map(ProfileSummary.fromJson)
      .toList();
});

/// Optimistic follow/unfollow toggle, keyed by the target user's id so
/// multiple Follow buttons for the same profile (feed + search + profile
/// screen) stay in sync without a full refetch.
class FollowNotifier extends StateNotifier<Map<String, bool>> {
  final Ref _ref;
  FollowNotifier(this._ref) : super({});

  bool isFollowing(String targetUserId, bool serverValue) {
    return state[targetUserId] ?? serverValue;
  }

  Future<void> toggle({
    required String targetUserId,
    required bool currentlyFollowing,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    state = {...state, targetUserId: !currentlyFollowing};

    try {
      if (currentlyFollowing) {
        await _db
            .from('follows')
            .delete()
            .eq('follower_id', user.id)
            .eq('following_id', targetUserId);
      } else {
        await _db.from('follows').insert({
          'follower_id': user.id,
          'following_id': targetUserId,
        });
      }
      _ref.invalidate(followingIdsProvider);
      _ref.invalidate(followerCountProvider(targetUserId));
      _ref.invalidate(followingCountProvider(user.id));
    } catch (_) {
      state = {...state, targetUserId: currentlyFollowing};
    }
  }
}

final followNotifierProvider =
    StateNotifierProvider<FollowNotifier, Map<String, bool>>((ref) {
  ref.watch(currentUserProvider);
  return FollowNotifier(ref);
});
