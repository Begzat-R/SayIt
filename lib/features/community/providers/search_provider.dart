import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../models/profile_summary.dart';

final _db = Supabase.instance.client;

/// Debounced by the search screen (see [SearchScreen._onChanged]) — this
/// provider only re-queries when the value here actually changes, so
/// typing doesn't fire a request per keystroke.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final searchResultsProvider =
    FutureProvider.autoDispose<List<ProfileSummary>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];

  final currentUserId = ref.watch(currentUserProvider)?.id;
  var builder = _db
      .from('profiles')
      .select('id, display_name')
      .ilike('display_name', '%$query%');
  if (currentUserId != null) {
    builder = builder.neq('id', currentUserId);
  }
  final rows = await builder.limit(30);
  // Blocked-relationship rows are already excluded server-side by the
  // profiles RLS policy (public.is_blocked) — nothing to filter here.
  return (rows as List)
      .map((r) => ProfileSummary.fromJson(r as Map<String, dynamic>))
      .toList();
});
