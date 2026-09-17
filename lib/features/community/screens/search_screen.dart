import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/profile_summary.dart';
import '../providers/follow_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/follow_button.dart';
import '../widgets/initial_avatar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resultsAsync = ref.watch(searchResultsProvider);
    final hasQuery = ref.watch(searchQueryProvider).trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              onChanged: _onChanged,
                              style: GoogleFonts.figtree(
                                  fontSize: 15, color: cs.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Search people…',
                                hintStyle: GoogleFonts.figtree(
                                  fontSize: 15,
                                  color: cs.onSurface.withValues(alpha: 0.35),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: !hasQuery
                  ? Center(
                      child: Text(
                        'Search for people by name.',
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    )
                  : resultsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (e, _) => Center(
                        child: Text(
                          'Could not search right now.',
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      data: (results) {
                        if (results.isEmpty) {
                          return Center(
                            child: Text(
                              'No one found.',
                              style: GoogleFonts.figtree(
                                fontSize: 14,
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: results.length,
                          itemBuilder: (context, index) =>
                              _ResultRow(profile: results[index]),
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

class _ResultRow extends ConsumerWidget {
  final ProfileSummary profile;
  const _ResultRow({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final followingIds = ref.watch(followingIdsProvider).value ?? {};
    final isFollowing = followingIds.contains(profile.id);

    return GestureDetector(
      onTap: () => context.push('/community/user/${profile.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            InitialAvatar(name: profile.displayName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                profile.displayName,
                style: GoogleFonts.figtree(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            FollowButton(
              targetUserId: profile.id,
              serverIsFollowing: isFollowing,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
