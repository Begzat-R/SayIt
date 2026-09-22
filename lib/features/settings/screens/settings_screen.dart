import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../services/auth_service.dart';
import '../../community/models/community_post.dart';
import '../../community/providers/follow_provider.dart';
import '../../community/providers/profile_provider.dart';
import '../../community/widgets/initial_avatar.dart';
import '../providers/daily_reminder_provider.dart';

const _kAppVersion = '1.0.0';
const _kTermsUrl = 'https://begzat-r.github.io/SayIt/terms.html';
const _kPrivacyUrl = 'https://begzat-r.github.io/SayIt/privacy.html';

Future<void> _openExternalLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open link.')),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName(String userId) async {
    final saved = await ref
        .read(profileEditProvider.notifier)
        .updateDisplayName(userId, _nameCtrl.text);
    if (saved && mounted) setState(() => _editing = false);
  }

  void _startEditing(String currentName) {
    _nameCtrl.text = currentName;
    setState(() => _editing = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ───────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Profile',
                  style: GoogleFonts.epilogue(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
            ),

            if (user == null) ...[
              // ─── Signed-out state ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in to save your name, track progress across devices, and share with the community.',
                        style: GoogleFonts.figtree(
                          fontSize: 15,
                          color: cs.onSurface.withValues(alpha: 0.55),
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => context.go('/community'),
                        child: Text(
                          'Go to Community to sign in',
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ─── Account section ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                sliver: SliverToBoxAdapter(
                  child: _AccountSection(
                    user: user,
                    nameCtrl: _nameCtrl,
                    editing: _editing,
                    onStartEdit: _startEditing,
                    onSave: _saveName,
                    onCancelEdit: () => setState(() => _editing = false),
                  ),
                ),
              ),
            ],

            // ─── Daily reminder section ───────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              sliver: SliverToBoxAdapter(
                child: _DailyReminderSection(cs: cs),
              ),
            ),

            // ─── Appearance section ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              sliver: SliverToBoxAdapter(
                child: _AppearanceSection(cs: cs),
              ),
            ),

            // ─── About section ────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              sliver: SliverToBoxAdapter(
                child: _AboutSection(cs: cs),
              ),
            ),

            // ─── Your Posts section (signed-in only) ──────────────────────
            if (user != null) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 1, color: cs.outline.withValues(alpha: 0.6)),
                      const SizedBox(height: 20),
                      Text(
                        'YOUR POSTS',
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.35),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _PostsSliver(),
            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
          ],
        ),
      ),
    );
  }
}

// ─── Account section ─────────────────────────────────────────────────────────

class _AccountSection extends ConsumerWidget {
  final dynamic user;
  final TextEditingController nameCtrl;
  final bool editing;
  final void Function(String) onStartEdit;
  final Future<void> Function(String) onSave;
  final VoidCallback onCancelEdit;

  const _AccountSection({
    required this.user,
    required this.nameCtrl,
    required this.editing,
    required this.onStartEdit,
    required this.onSave,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final cs = Theme.of(context).colorScheme;
    final profileAsync = widgetRef.watch(myProfileProvider);
    final editState = widgetRef.watch(profileEditProvider);
    final isSaving = editState is AsyncLoading;

    return profileAsync.when(
      loading: () => const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      // myProfileProvider is autoDispose, but the bottom-tab shell keeps
      // this screen mounted (just offstage) via IndexedStack so tab
      // switches don't rebuild it — so a fetch that failed once (e.g. a
      // transient network blip) never gets a second attempt on its own,
      // and this stayed stuck on the error text for the rest of the
      // session even after connectivity came back. A manual retry is the
      // only way out short of restarting the app.
      error: (e, _) => GestureDetector(
        onTap: () => widgetRef.invalidate(myProfileProvider),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Text(
              'Could not load profile. ',
              style: GoogleFonts.figtree(
                  fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
            Text(
              'Tap to retry',
              style: GoogleFonts.figtree(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
      data: (profile) {
        final displayName = profile?['display_name'] as String? ?? '';
        final effectiveName =
            displayName.isNotEmpty ? displayName : user.email ?? '?';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar left, name/email right in a Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InitialAvatar(name: effectiveName, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: editing
                      ? TextField(
                          controller: nameCtrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.figtree(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Your name',
                            hintStyle: GoogleFonts.figtree(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                          onSubmitted: (_) => onSave(user.id),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    effectiveName,
                                    style: GoogleFonts.epilogue(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                      letterSpacing: -0.2,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => onStartEdit(displayName),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                            if (displayName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                user.email ?? '',
                                style: GoogleFonts.figtree(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),

            if (!editing) ...[
              const SizedBox(height: 10),
              _FollowCountsRow(userId: user.id, displayName: effectiveName),
            ],

            // Save/Cancel (editing only)
            if (editing) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: isSaving ? null : () => onSave(user.id),
                    // The app-wide ElevatedButtonTheme sets minimumSize:
                    // Size(double.infinity, 52) — fine for full-width
                    // buttons, but bare in a Row (as here, next to
                    // Cancel) that infinite width has nothing to resolve
                    // against and crashes layout with no on-screen error.
                    // Same class of bug as the profile screen's Message
                    // button and the message-request Accept button.
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Save',
                            style: GoogleFonts.figtree(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onCancelEdit,
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // Sign out
            GestureDetector(
              onTap: () =>
                  widgetRef.read(authNotifierProvider.notifier).signOut(),
              child: Text(
                'Sign out',
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FollowCountsRow extends ConsumerWidget {
  final String userId;
  final String displayName;
  const _FollowCountsRow({required this.userId, required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final followerCount = ref.watch(followerCountProvider(userId));
    final followingCount = ref.watch(followingCountProvider(userId));

    Widget count(String label, int? value, int initialTab) {
      return GestureDetector(
        onTap: () => context.push(
          '/community/user/$userId/connections',
          extra: {'displayName': displayName, 'initialTab': initialTab},
        ),
        child: Text(
          '${value ?? 0} $label',
          style: GoogleFonts.figtree(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    return Row(
      children: [
        count('followers', followerCount.value, 0),
        const SizedBox(width: 14),
        count('following', followingCount.value, 1),
      ],
    );
  }
}

// ─── Daily reminder section ──────────────────────────────────────────────────

class _DailyReminderSection extends ConsumerWidget {
  final ColorScheme cs;
  const _DailyReminderSection({required this.cs});

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      // Force a 12-hour AM/PM picker regardless of the device's system
      // time format setting, so the user can always explicitly choose
      // AM vs PM here. This only changes how the picker displays the
      // value — TimeOfDay.hour (and everything scheduleDaily/_nextInstanceOfTime
      // do with it in motivation_service.dart) is always 24-hour internally,
      // so this can't shift what time actually gets scheduled.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await ref.read(dailyReminderProvider.notifier).setTime(picked);
    }
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyReminderProvider);
    final notifier = ref.read(dailyReminderProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: cs.outline.withValues(alpha: 0.6)),
        const SizedBox(height: 20),
        Text(
          'DAILY REMINDER',
          style: GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.35),
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Daily reminder',
                  style: GoogleFonts.figtree(fontSize: 14, color: cs.onSurface),
                ),
              ),
              if (state.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: state.enabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) => notifier.setEnabled(value),
                ),
            ],
          ),
        ),
        if (state.enabled)
          GestureDetector(
            onTap: () => _pickTime(context, ref, state.time),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Time',
                      style: GoogleFonts.figtree(
                          fontSize: 14, color: cs.onSurface),
                    ),
                  ),
                  Text(
                    _formatTime(state.time),
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        if (state.permissionDeniedMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            state.permissionDeniedMessage!,
            style: GoogleFonts.figtree(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              notifier.dismissPermissionMessage();
              openAppSettings();
            },
            child: Text(
              'Open app settings',
              style: GoogleFonts.figtree(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Appearance section ──────────────────────────────────────────────────────

class _AppearanceSection extends ConsumerWidget {
  final ColorScheme cs;
  const _AppearanceSection({required this.cs});

  static const _options = [
    (ThemeMode.system, 'System'),
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: cs.outline.withValues(alpha: 0.6)),
        const SizedBox(height: 20),
        Text(
          'APPEARANCE',
          style: GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.35),
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              for (final (mode, label) in _options)
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).setThemeMode(mode),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: mode == current
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: mode == current
                              ? Colors.white
                              : cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── About section ────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  final ColorScheme cs;
  const _AboutSection({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: cs.outline.withValues(alpha: 0.6)),
        const SizedBox(height: 20),
        Text(
          'ABOUT',
          style: GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.35),
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        _SettingsRow(
          label: 'Terms of Service',
          onTap: () => _openExternalLink(context, _kTermsUrl),
          showChevron: true,
        ),
        _SettingsRow(
          label: 'Privacy Policy',
          onTap: () => _openExternalLink(context, _kPrivacyUrl),
          showChevron: true,
        ),
        _SettingsRow(
          label: 'Version',
          trailing: _kAppVersion,
          showChevron: false,
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingsRow({
    required this.label,
    this.trailing,
    this.onTap,
    required this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
            if (showChevron)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Posts sliver ─────────────────────────────────────────────────────────────

class _PostsSliver extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(myPostsProvider);
    final cs = Theme.of(context).colorScheme;

    return postsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 8, 32, 0),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (posts) {
        if (posts.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                "You haven't posted yet.",
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _PostRow(
                post: posts[index],
                isLast: index == posts.length - 1,
              ),
              childCount: posts.length,
            ),
          ),
        );
      },
    );
  }
}

class _PostRow extends StatelessWidget {
  final CommunityPost post;
  final bool isLast;
  const _PostRow({required this.post, required this.isLast});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom:
                    BorderSide(color: cs.outline.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _relativeTime(post.createdAt),
            style: GoogleFonts.figtree(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            style: GoogleFonts.figtree(
              fontSize: 14,
              color: cs.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite_outline_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(width: 3),
              Text(
                '${post.likeCount}',
                style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(width: 3),
              Text(
                '${post.commentCount}',
                style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
