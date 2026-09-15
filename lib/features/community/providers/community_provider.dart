import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../models/community_post.dart';
import '../models/community_reply.dart';

final _db = Supabase.instance.client;

// ─── Posts ───────────────────────────────────────────────────────────────────

Future<List<CommunityPost>> _fetchPosts(String? currentUserId) async {
  final rows = await _db
      .from('community_posts')
      .select(
        'id, user_id, body, created_at, '
        'profiles(display_name), '
        'post_likes(user_id), '
        'community_replies(id)',
      )
      .order('created_at', ascending: false)
      .limit(50);
  return (rows as List)
      .map((r) => CommunityPost.fromJson(
            r as Map<String, dynamic>,
            currentUserId: currentUserId,
          ))
      .toList();
}

final communityPostsProvider =
    StreamProvider.autoDispose<List<CommunityPost>>((ref) {
  final currentUserId = ref.watch(currentUserProvider)?.id;
  final controller = StreamController<List<CommunityPost>>();

  void fetchAndEmit() {
    _fetchPosts(currentUserId).then(controller.add).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });
  }

  fetchAndEmit();

  final channel = _db
      .channel('community_posts_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'community_posts',
        callback: (_) => fetchAndEmit(),
      )
      .subscribe();

  ref.onDispose(() {
    _db.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

// ─── New post ─────────────────────────────────────────────────────────────────

class NewPostNotifier extends StateNotifier<AsyncValue<void>> {
  NewPostNotifier() : super(const AsyncValue.data(null));

  Future<bool> submit(String body) async {
    final user = _db.auth.currentUser;
    if (user == null || body.trim().isEmpty) return false;
    state = const AsyncValue.loading();
    try {
      await _db.from('community_posts').insert({
        'user_id': user.id,
        'body': body.trim(),
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final newPostProvider =
    StateNotifierProvider.autoDispose<NewPostNotifier, AsyncValue<void>>((ref) {
  return NewPostNotifier();
});

// ─── Likes (optimistic) ───────────────────────────────────────────────────────

class LikeState {
  final bool isLiked;
  final int count;
  const LikeState({required this.isLiked, required this.count});
}

class LikeNotifier extends StateNotifier<Map<String, LikeState>> {
  LikeNotifier() : super({});

  Future<void> toggle({
    required String postId,
    required bool currentIsLiked,
    required int currentCount,
    required String userId,
  }) async {
    // Optimistic update
    state = {
      ...state,
      postId: LikeState(
        isLiked: !currentIsLiked,
        count: currentIsLiked ? currentCount - 1 : currentCount + 1,
      ),
    };

    try {
      if (currentIsLiked) {
        await _db
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await _db.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
    } catch (_) {
      // Revert on failure
      state = {
        ...state,
        postId: LikeState(isLiked: currentIsLiked, count: currentCount),
      };
    }
  }
}

// Recreate (clearing overrides) whenever the signed-in user changes.
final likeNotifierProvider =
    StateNotifierProvider<LikeNotifier, Map<String, LikeState>>((ref) {
  ref.watch(currentUserProvider);
  return LikeNotifier();
});

// ─── Replies (per-post, real-time) ───────────────────────────────────────────

Future<List<CommunityReply>> _fetchReplies(String postId) async {
  final rows = await _db
      .from('community_replies')
      .select('id, post_id, user_id, body, created_at, profiles(display_name)')
      .eq('post_id', postId)
      .order('created_at', ascending: true);
  return (rows as List)
      .map((r) => CommunityReply.fromJson(r as Map<String, dynamic>))
      .toList();
}

final postRepliesProvider =
    StreamProvider.autoDispose.family<List<CommunityReply>, String>((ref, postId) {
  final controller = StreamController<List<CommunityReply>>();

  void fetchAndEmit() {
    _fetchReplies(postId).then(controller.add).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });
  }

  fetchAndEmit();

  final channel = _db
      .channel('replies_$postId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'community_replies',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
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

// ─── Add reply ────────────────────────────────────────────────────────────────

class AddReplyNotifier extends StateNotifier<AsyncValue<void>> {
  AddReplyNotifier() : super(const AsyncValue.data(null));

  Future<bool> submit(String postId, String body) async {
    final user = _db.auth.currentUser;
    if (user == null || body.trim().isEmpty) return false;
    state = const AsyncValue.loading();
    try {
      await _db.from('community_replies').insert({
        'post_id': postId,
        'user_id': user.id,
        'body': body.trim(),
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final addReplyProvider =
    StateNotifierProvider.autoDispose<AddReplyNotifier, AsyncValue<void>>((ref) {
  return AddReplyNotifier();
});
