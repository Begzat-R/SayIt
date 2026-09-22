import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/community/models/community_post.dart';
import 'features/community/screens/community_screen.dart';
import 'features/community/screens/daily_post_screen.dart';
import 'features/community/screens/follow_list_screen.dart';
import 'features/community/screens/post_detail_screen.dart';
import 'features/community/screens/search_screen.dart';
import 'features/community/screens/user_profile_screen.dart';
import 'features/messages/screens/messages_screen.dart';
import 'features/messages/screens/thread_screen.dart';
import 'features/messages/widgets/new_message_banner.dart';
import 'features/notifications/providers/notifications_provider.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/practice/screens/breathing_screen.dart';
import 'features/practice/screens/practice_screen.dart';
import 'features/progress/screens/progress_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/situations/screens/situations_screen.dart';
import 'features/splash/screens/splash_screen.dart';

/// Set to the live [GoRouter] whenever `_routerProvider` builds one, so a
/// notification tap (which fires outside the widget tree, via a static
/// callback in MotivationService) can still navigate.
GoRouter? appRouter;

/// Overridden in main.dart when the app was cold-started by tapping the
/// daily reminder notification, so the router opens straight to Practice
/// instead of the splash screen.
final launchedFromNotificationProvider = Provider<bool>((ref) => false);

CustomTransitionPage<void> _slideFadePage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

final _routerProvider = Provider<GoRouter>((ref) {
  final launchedFromNotification = ref.watch(launchedFromNotificationProvider);
  final router = GoRouter(
    initialLocation: launchedFromNotification ? '/situations' : '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _slideFadePage(state.pageKey, const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _slideFadePage(state.pageKey, const OnboardingScreen()),
      ),
      // StatefulShellRoute.indexedStack keeps all four tab screens alive in
      // an IndexedStack instead of disposing and rebuilding the destination
      // screen on every tab switch. The previous plain ShellRoute rebuilt
      // (and, for Community, re-fetched over the network) the whole screen
      // on every switch while also playing a 300ms transition on top of
      // that rebuild — measured as real jank (dropped frames) even in
      // profile builds. Switching branches is now an instant index change.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/situations',
              builder: (context, state) => const SituationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/community',
              builder: (context, state) => const CommunityScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/progress',
              builder: (context, state) => const ProgressScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/practice/:scenarioId',
        pageBuilder: (context, state) {
          final scenarioId = state.pathParameters['scenarioId']!;
          return _slideFadePage(
            state.pageKey,
            PracticeScreen(scenarioId: scenarioId),
          );
        },
      ),
      GoRoute(
        path: '/post/:postId',
        pageBuilder: (context, state) {
          final postId = state.pathParameters['postId']!;
          final post = state.extra as CommunityPost?;
          final scrollToComments =
              state.uri.queryParameters['scrollToComments'] == 'true';
          return _slideFadePage(
            state.pageKey,
            PostDetailScreen(
              postId: postId,
              initialPost: post,
              scrollToComments: scrollToComments,
            ),
          );
        },
      ),
      GoRoute(
        path: '/community/search',
        pageBuilder: (context, state) =>
            _slideFadePage(state.pageKey, const SearchScreen()),
      ),
      GoRoute(
        path: '/community/daily-post',
        pageBuilder: (context, state) =>
            _slideFadePage(state.pageKey, const DailyPostScreen()),
      ),
      GoRoute(
        path: '/community/user/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return _slideFadePage(state.pageKey, UserProfileScreen(userId: userId));
        },
      ),
      GoRoute(
        path: '/community/user/:userId/connections',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _slideFadePage(
            state.pageKey,
            FollowListScreen(
              userId: userId,
              displayName: extra['displayName'] as String? ?? 'this user',
              initialTab: extra['initialTab'] as int? ?? 0,
            ),
          );
        },
      ),
      GoRoute(
        path: '/messages',
        pageBuilder: (context, state) =>
            _slideFadePage(state.pageKey, const MessagesScreen()),
      ),
      GoRoute(
        path: '/messages/compose/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final displayName = state.extra as String? ?? 'this user';
          return _slideFadePage(
            state.pageKey,
            ThreadScreen(otherUserId: userId, otherDisplayName: displayName),
          );
        },
      ),
      GoRoute(
        path: '/messages/thread/:threadId',
        pageBuilder: (context, state) {
          final threadId = state.pathParameters['threadId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _slideFadePage(
            state.pageKey,
            ThreadScreen(
              threadId: threadId,
              otherUserId: extra['otherUserId'] as String? ?? '',
              otherDisplayName: extra['otherDisplayName'] as String? ?? 'Conversation',
            ),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _slideFadePage(state.pageKey, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/breathing',
        pageBuilder: (context, state) =>
            _slideFadePage(state.pageKey, const BreathingScreen()),
      ),
    ],
  );
  appRouter = router;
  ref.onDispose(() {
    if (identical(appRouter, router)) appRouter = null;
    router.dispose();
  });
  return router;
});

class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Cadence',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => NewMessageBannerOverlay(child: child!),
    );
  }
}

class _AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  // initialLocation resets the branch's own navigation stack when the
  // already-active tab is tapped again, matching typical bottom-nav UX.
  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    // Watched here (rather than only inside CommunityScreen) so the dot
    // stays live app-wide, not just while the Community tab happens to be
    // mounted — _AppShell persists across every shell tab.
    final hasUnreadNotifications = ref.watch(unreadNotificationCountProvider) > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: navigationShell,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, navConstraints) {
                final totalWidth = navConstraints.maxWidth;
                return Row(
                  children: [
                    _NavItem(
                      totalWidth: totalWidth,
                      icon: Icons.bolt_outlined,
                      label: 'Practice',
                      isActive: index == 0,
                      onTap: () => _goBranch(0),
                    ),
                    _NavItem(
                      totalWidth: totalWidth,
                      icon: Icons.group_outlined,
                      label: 'Community',
                      isActive: index == 1,
                      onTap: () => _goBranch(1),
                      showBadge: hasUnreadNotifications,
                    ),
                    _NavItem(
                      totalWidth: totalWidth,
                      icon: Icons.bar_chart,
                      label: 'Progress',
                      isActive: index == 2,
                      onTap: () => _goBranch(2),
                    ),
                    _NavItem(
                      totalWidth: totalWidth,
                      icon: Icons.person_outline,
                      label: 'Profile',
                      isActive: index == 3,
                      onTap: () => _goBranch(3),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final double totalWidth;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool showBadge;

  const _NavItem({
    required this.totalWidth,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.showBadge = false,
  });

  // hPad is the horizontal padding on each side of the active pill content.
  // The label SizedBox is computed precisely from the slot width so the inner
  // Row(mainAxisSize: min) can never exceed its parent and trigger overflow.
  static const double _hPad = 12.0;
  static const double _iconSize = 20.0;
  static const double _gap = 6.0;

  // The active tab is the only one that needs room for a label, so it gets
  // a bigger share of the row than the three icon-only tabs (2 parts out of
  // 5, vs. 1 each) — with equal shares all round, the label's slot was only
  // ever a flat quarter of the bar width and truncated to "Practi…" /
  // "Communi…" on anything narrower than a phablet. Exactly one of the 4
  // tabs is active at a time, so the total is always 2+1+1+1 = 5.
  static const double _totalShares = 5.0;

  @override
  Widget build(BuildContext context) {
    final targetSlotWidth = (isActive ? 2 : 1) / _totalShares * totalWidth;

    // Previously the slot width came from Expanded(flex: isActive ? 2 : 1),
    // which snaps instantly on tab switch, while the label's width shrank
    // via a separate AnimatedSize over 220ms — the two were driven by
    // different clocks, so mid-transition the Row still demanded its old
    // (wide) width inside an already-narrowed slot and threw a RenderFlex
    // overflow ("red flash") on every switch. Driving both the slot width
    // and the label width from this single TweenAnimationBuilder value
    // keeps them in lockstep on every frame, not just at rest.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: targetSlotWidth, end: targetSlotWidth),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      builder: (context, slotWidth, child) {
        // Available width for the label after padding, icon, and gap are accounted for.
        final labelWidth = isActive
            ? (slotWidth - 2 * _hPad - _iconSize - _gap).clamp(0.0, double.infinity)
            : 0.0;

        return SizedBox(
          width: slotWidth,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: _hPad,
                  vertical: 10.0,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          icon,
                          size: _iconSize,
                          color:
                              isActive ? Colors.white : const Color(0xFF9E9E9E),
                        ),
                        if (showBadge)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.primary
                                      : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Width comes from the same slotWidth as the SizedBox
                    // above, computed in the same builder call, so the Row
                    // can never exceed (icon + gap + labelWidth) — which
                    // equals exactly slotWidth - 2*_hPad — at any point
                    // during the animation, not just once it settles.
                    SizedBox(
                      width: labelWidth > 0 ? labelWidth + _gap : 0,
                      child: isActive
                          ? Padding(
                              padding: const EdgeInsets.only(left: _gap),
                              // FittedBox is the last-resort safety net: on
                              // a very narrow phone combined with a large
                              // system font size, even the rebalanced slot
                              // above can run out of room — this shrinks
                              // the label instead of clipping it.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  style: GoogleFonts.figtree(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
