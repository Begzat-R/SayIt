import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/press_trigger.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    if (mounted) context.go('/situations');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _PageOne(onNext: _nextPage),
                  _PageTwo(onNext: _nextPage),
                  _PageThree(onFinish: _finish),
                ],
              ),
            ),
            _PageIndicator(currentPage: _currentPage, pageCount: 3),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const _PageIndicator({required this.currentPage, required this.pageCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : cs.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _PageOne extends StatelessWidget {
  final VoidCallback onNext;
  const _PageOne({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            'Cadence',
            style: GoogleFonts.epilogue(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -2.0,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Practice real situations\nbefore you\'re actually\nin them.',
            style: GoogleFonts.epilogue(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'A space to rehearse the calls, conversations, and moments that feel hard — without the stakes.',
            style: GoogleFonts.figtree(
              fontSize: 15,
              color: cs.onSurface.withValues(alpha: 0.55),
              height: 1.65,
            ),
          ),
          const Spacer(flex: 3),
          AppButton.primary(label: 'Get started', onPressed: onNext),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

const List<String> _kGoals = [
  'Feel more confident in real situations',
  'Work through blocks',
  'Connect with others who stutter',
  'Just explore',
];

class _PageTwo extends ConsumerWidget {
  final VoidCallback onNext;
  const _PageTwo({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selectedGoals = ref.watch(onboardingProvider).selectedGoals;
    final notifier = ref.read(onboardingProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Text(
            'What brings\nyou here?',
            style: GoogleFonts.epilogue(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pick everything that fits.',
            style: GoogleFonts.figtree(
              fontSize: 15,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 10,
            runSpacing: 14,
            children: _kGoals.map((goal) {
              final selected = selectedGoals.contains(goal);
              return PressTrigger(
                scaleTo: 0.96,
                child: GestureDetector(
                  onTap: () => notifier.toggleGoal(goal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.07)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : cs.onSurface.withValues(alpha: 0.2),
                        width: selected ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      goal,
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? AppColors.primary
                            : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(flex: 2),
          AppButton.primary(label: 'Continue', onPressed: onNext),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PageThree extends ConsumerStatefulWidget {
  final Future<void> Function() onFinish;
  const _PageThree({required this.onFinish});

  @override
  ConsumerState<_PageThree> createState() => _PageThreeState();
}

class _PageThreeState extends ConsumerState<_PageThree> {
  late final TextEditingController _nameController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(() {
      ref.read(onboardingProvider.notifier).setName(_nameController.text.trim());
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleStart() async {
    setState(() => _loading = true);
    await widget.onFinish();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What should we\ncall you?',
                    style: GoogleFonts.epilogue(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Optional. You can change this later.',
                    style: GoogleFonts.figtree(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.figtree(fontSize: 16, color: cs.onSurface),
                    decoration: const InputDecoration(labelText: 'Name or nickname'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No account needed to get started. Sign up later to share with the community or sync across devices.',
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.45),
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppButton.primary(
            label: _loading ? 'Starting...' : 'Start practicing',
            onPressed: _loading ? null : _handleStart,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _handleStart,
              child: Text(
                'Skip',
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
