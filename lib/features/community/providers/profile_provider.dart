import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../models/community_post.dart';

final _db = Supabase.instance.client;

// ─── Current user's profile row ───────────────────────────────────────────────

final myProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final data = await _db
      .from('profiles')
      .select('id, display_name, created_at')
      .eq('id', user.id)
      .maybeSingle();
  return data;
});

// ─── Current user's own posts ─────────────────────────────────────────────────

final myPostsProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final rows = await _db
      .from('community_posts')
      .select(
        'id, user_id, body, created_at, situation_tag, '
        'profiles(display_name), '
        'post_likes(user_id), '
        'community_replies(id)',
      )
      .eq('user_id', user.id)
      .order('created_at', ascending: false);
  return (rows as List)
      .map((r) => CommunityPost.fromJson(
            r as Map<String, dynamic>,
            currentUserId: user.id,
          ))
      .toList();
});

// ─── Another user's public profile ───────────────────────────────────────────

final publicProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, userId) async {
  return await _db
      .from('profiles')
      .select('id, display_name, created_at')
      .eq('id', userId)
      .maybeSingle();
});

final userPostsProvider =
    FutureProvider.autoDispose.family<List<CommunityPost>, String>(
        (ref, userId) async {
  final currentUserId = ref.watch(currentUserProvider)?.id;
  final rows = await _db
      .from('community_posts')
      .select(
        'id, user_id, body, created_at, situation_tag, '
        'profiles(display_name), '
        'post_likes(user_id), '
        'community_replies(id)',
      )
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return (rows as List)
      .map((r) => CommunityPost.fromJson(
            r as Map<String, dynamic>,
            currentUserId: currentUserId,
          ))
      .toList();
});

// ─── Profile edit ─────────────────────────────────────────────────────────────

class ProfileEditNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  ProfileEditNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> updateDisplayName(String userId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    state = const AsyncValue.loading();
    try {
      await _db.from('profiles').update({'display_name': trimmed}).eq('id', userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', trimmed);
      _ref.invalidate(myProfileProvider);
      _ref.invalidate(myPostsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final profileEditProvider =
    StateNotifierProvider.autoDispose<ProfileEditNotifier, AsyncValue<void>>((ref) {
  return ProfileEditNotifier(ref);
});
