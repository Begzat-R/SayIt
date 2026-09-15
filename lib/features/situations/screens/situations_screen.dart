import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/press_trigger.dart';
import '../data/scenarios.dart';
import '../models/scenario.dart';
import '../providers/practice_provider.dart';

class SituationsScreen extends ConsumerStatefulWidget {
  const SituationsScreen({super.key});

  @override
  ConsumerState<SituationsScreen> createState() => _SituationsScreenState();
}

class _SituationsScreenState extends ConsumerState<SituationsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  late final List<CurvedAnimation> _itemAnims;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200 + kScenarios.length * 55),
    );
    _itemAnims = List.generate(kScenarios.length, (i) {
      final start = (i * 0.08).clamp(0.0, 0.75);
      final end = (start + 0.5).clamp(0.1, 1.0);
      return CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    for (final a in _itemAnims) {
      a.dispose();
    }
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sessions = ref.watch(practiceSessionsProvider);
    final practicedIds = sessions.map((s) => s.scenarioId).toSet();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ───────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Situations',
                      style: GoogleFonts.epilogue(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pick one. Take your time.',
                      style: GoogleFonts.figtree(
                        fontSize: 15,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Breathing card ────────────────────────────────────
                    _BreathingCard(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ─── Scenario list ────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final scenario = kScenarios[index];
                    final isLast = index == kScenarios.length - 1;
                    final anim = _itemAnims[index];
                    final practiced = practicedIds.contains(scenario.id);

                    return AnimatedBuilder(
                      animation: anim,
                      builder: (context, child) {
                        final t = anim.value;
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 20),
                            child: child,
                          ),
                        );
                      },
                      child: _ScenarioItem(
                        scenario: scenario,
                        isLast: isLast,
                        practiced: practiced,
                        onTap: () => context.push('/practice/${scenario.id}'),
                      ),
                    );
                  },
                  childCount: kScenarios.length,
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }
}

// ─── Breathing suggestion card ────────────────────────────────────────────────

class _BreathingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressTrigger(
      scaleTo: 0.98,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTap: () => context.push('/breathing'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.air,
                size: 17,
                color: AppColors.primary.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Feeling anxious? Try a breathing exercise first.',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 14,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scenario item ────────────────────────────────────────────────────────────

class _ScenarioItem extends StatelessWidget {
  final Scenario scenario;
  final VoidCallback onTap;
  final bool isLast;
  final bool practiced;

  const _ScenarioItem({
    required this.scenario,
    required this.onTap,
    required this.isLast,
    required this.practiced,
  });

  IconData _iconFor(String iconName) {
    switch (iconName) {
      case 'coffee':
        return Icons.local_cafe_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'user':
        return Icons.person_outline;
      case 'briefcase':
        return Icons.work_outline;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'map_pin':
        return Icons.place_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PressTrigger(
      scaleTo: 0.98,
      opacityTo: 0.8,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: cs.outline.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    _iconFor(scenario.iconName),
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        scenario.category.toUpperCase(),
                        style: GoogleFonts.figtree(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary.withValues(alpha: 0.6),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scenario.title,
                      style: GoogleFonts.figtree(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scenario.context,
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Practiced indicator or arrow
              if (practiced)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward,
                  size: 15,
                  color: cs.onSurface.withValues(alpha: 0.25),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
