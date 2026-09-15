import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

enum _Technique { noseIn, mouthIn }

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  _Technique _technique = _Technique.noseIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1733), Color(0xFF08070E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Pulsing orb
              AnimatedBuilder(
                animation: _scale,
                builder: (context, _) {
                  final s = _scale.value;
                  const base = 200.0;
                  return SizedBox(
                    width: base * 1.6,
                    height: base * 1.6,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow
                        Transform.scale(
                          scale: s,
                          child: Container(
                            width: base * 1.6,
                            height: base * 1.6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2D2A4A)
                                  .withValues(alpha: 0.15 * s),
                            ),
                          ),
                        ),
                        // Mid ring
                        Transform.scale(
                          scale: s,
                          child: Container(
                            width: base,
                            height: base,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  const Color(0xFF2D2A4A).withValues(alpha: 0.50),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        // Inner core
                        Transform.scale(
                          scale: s * 0.50,
                          child: Container(
                            width: base,
                            height: base,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 52),

              Text(
                'Focus.',
                style: GoogleFonts.epilogue(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Close your eyes.',
                style: GoogleFonts.figtree(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 16),

              // Technique caption
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _technique == _Technique.noseIn
                        ? 'Breathe in through your nose, out through your mouth'
                        : 'Breathe in through your mouth, out through your nose',
                    key: ValueKey(_technique),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.3),
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Technique toggle pills
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  children: [
                    _TechniquePill(
                      label: 'Nose in · Mouth out',
                      isActive: _technique == _Technique.noseIn,
                      onTap: () =>
                          setState(() => _technique = _Technique.noseIn),
                    ),
                    const SizedBox(width: 8),
                    _TechniquePill(
                      label: 'Mouth in · Nose out',
                      isActive: _technique == _Technique.mouthIn,
                      onTap: () =>
                          setState(() => _technique = _Technique.mouthIn),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechniquePill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TechniquePill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  Colors.white.withValues(alpha: isActive ? 0.22 : 0.10),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.38),
            ),
          ),
        ),
      ),
    );
  }
}
