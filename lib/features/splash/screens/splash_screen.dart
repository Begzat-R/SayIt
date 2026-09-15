import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _line1Ctrl;
  late final AnimationController _line2Ctrl;
  late final AnimationController _buttonCtrl;

  @override
  void initState() {
    super.initState();
    _line1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _line2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _buttonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool('onboarding_complete') ?? false) {
      context.go('/situations');
      return;
    }
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 350));
    await _line1Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 480));
    await _line2Ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    await _buttonCtrl.forward();
  }

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _buttonCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_complete') ?? false;
    if (mounted) {
      context.go(done ? '/situations' : '/onboarding');
    }
  }

  Widget _animatedLine(AnimationController ctrl, String text, TextStyle style) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final t = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic).value;
        return Transform.translate(
          offset: Offset(0, (1 - t) * 24),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: Text(text, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final line1Style = GoogleFonts.epilogue(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
      letterSpacing: -0.3,
      height: 1.2,
    );
    final line2Style = GoogleFonts.epilogue(
      fontSize: 36,
      fontWeight: FontWeight.w500,
      color: cs.onSurface.withValues(alpha: 0.5),
      letterSpacing: -0.3,
      height: 1.2,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              _animatedLine(_line1Ctrl, 'Some words\nget stuck.', line1Style),
              const SizedBox(height: 20),
              _animatedLine(
                _line2Ctrl,
                'Practice makes\nthem less scary.',
                line2Style,
              ),
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _buttonCtrl,
                builder: (context, child) {
                  final t = CurvedAnimation(
                    parent: _buttonCtrl,
                    curve: Curves.easeOutCubic,
                  ).value;
                  return Opacity(opacity: t, child: child);
                },
                child: GestureDetector(
                  onTap: _continue,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.figtree(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
