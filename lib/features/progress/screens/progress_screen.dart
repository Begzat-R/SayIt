import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../features/situations/data/scenarios.dart';
import '../../../features/situations/providers/practice_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(practiceSessionsProvider);
    final weekCount = ref.watch(thisWeekSessionCountProvider);
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final today = DateTime(now.year, now.month, now.day);

    final weekDays = List.generate(7, (i) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final count = sessions.where((s) {
        final d = s.timestamp;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
      return _DayData(day: day, count: count);
    });

    final recentSessions = sessions.reversed.take(10).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This week',
                      style: GoogleFonts.epilogue(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _WeekGrid(days: weekDays, today: today),
                    const SizedBox(height: 32),
                    _CountLine(weekCount: weekCount, cs: cs),
                    const SizedBox(height: 40),
                    if (recentSessions.isNotEmpty) ...[
                      Text(
                        'RECENT',
                        style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.35),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            if (recentSessions.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final session = recentSessions[index];
                      final isLast = index == recentSessions.length - 1;
                      return _SessionRow(
                        title: _scenarioTitle(session.scenarioId),
                        timestamp: session.timestamp,
                        feltGood: session.feltGood,
                        isLast: isLast,
                      );
                    },
                    childCount: recentSessions.length,
                  ),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  static String _scenarioTitle(String id) {
    try {
      return kScenarios.firstWhere((s) => s.id == id).title;
    } catch (_) {
      return id;
    }
  }
}

// ─── Week grid ────────────────────────────────────────────────────────────────

class _DayData {
  final DateTime day;
  final int count;
  const _DayData({required this.day, required this.count});
}

class _WeekGrid extends StatelessWidget {
  final List<_DayData> days;
  final DateTime today;

  const _WeekGrid({required this.days, required this.today});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final d = days[i];
        final isToday = d.day == today;
        final isFuture = d.day.isAfter(today);
        return _DayCell(
          label: _labels[i],
          count: d.count,
          isToday: isToday,
          isFuture: isFuture,
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final int count;
  final bool isToday;
  final bool isFuture;

  const _DayCell({
    required this.label,
    required this.count,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final practiced = count > 0;

    Color circleColor;
    Color borderColor;
    Color labelColor;

    if (practiced) {
      circleColor = AppColors.primary;
      borderColor = AppColors.primary;
      labelColor = AppColors.primary;
    } else if (isToday) {
      circleColor = Colors.transparent;
      borderColor = AppColors.primary.withValues(alpha: 0.45);
      labelColor = AppColors.primary.withValues(alpha: 0.7);
    } else if (isFuture) {
      circleColor = Colors.transparent;
      borderColor = cs.onSurface.withValues(alpha: 0.1);
      labelColor = cs.onSurface.withValues(alpha: 0.2);
    } else {
      circleColor = Colors.transparent;
      borderColor = cs.onSurface.withValues(alpha: 0.18);
      labelColor = cs.onSurface.withValues(alpha: 0.35);
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: practiced
              ? const Center(
                  child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                )
              : isToday
                  ? Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: isToday || practiced ? FontWeight.w600 : FontWeight.w400,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

// ─── Count / empty state ──────────────────────────────────────────────────────

class _CountLine extends StatelessWidget {
  final int weekCount;
  final ColorScheme cs;

  const _CountLine({required this.weekCount, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (weekCount == 0) {
      return Row(
        children: [
          Icon(
            Icons.mic_none,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Nothing yet. Pick a situation and go.',
              style: GoogleFonts.figtree(
                fontSize: 15,
                color: cs.onSurface.withValues(alpha: 0.45),
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$weekCount',
            style: GoogleFonts.epilogue(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
          TextSpan(
            text: '  ${weekCount == 1 ? 'situation' : 'situations'}\nthis week.',
            style: GoogleFonts.figtree(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session row ─────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final String title;
  final DateTime timestamp;
  final bool feltGood;
  final bool isLast;

  const _SessionRow({
    required this.title,
    required this.timestamp,
    required this.feltGood,
    required this.isLast,
  });

  String _formatTime(DateTime dt) {
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
                bottom: BorderSide(
                  color: cs.outline.withValues(alpha: 0.7),
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 14, top: 1),
            decoration: BoxDecoration(
              color: feltGood
                  ? AppColors.gold.withValues(alpha: 0.85)
                  : cs.onSurface.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.figtree(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatTime(timestamp),
            style: GoogleFonts.figtree(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }
}
