import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/press_trigger.dart';
import '../../../features/situations/data/scenarios.dart';
import '../../../features/situations/models/scenario.dart';
import '../../../features/situations/providers/practice_provider.dart';
import '../../../services/audio_service.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  final String scenarioId;
  const PracticeScreen({super.key, required this.scenarioId});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  String? _recordingPath;
  bool _isDone = false;
  // Guards against a second tap firing while start/stop is still in
  // flight — without this, a tap that lands while stopRecording() is
  // awaiting could read the still-true isRecording state and call
  // startRecording() again, racing the in-progress stop.
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.09).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    _pulseController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Scenario? get _scenario {
    try {
      return kScenarios.firstWhere((s) => s.id == widget.scenarioId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleRecording() async {
    if (_toggling) return;
    _toggling = true;
    try {
      final audioService = ref.read(audioServiceProvider.notifier);
      final audioState = ref.read(audioServiceProvider);

      if (audioState.isRecording) {
        final path = await audioService.stopRecording();
        _pulseController.stop();
        _pulseController.value = 0;
        HapticFeedback.lightImpact();
        setState(() {
          _recordingPath = path;
          _isDone = true;
        });
      } else {
        setState(() {
          _isDone = false;
          _recordingPath = null;
        });
        await audioService.startRecording();
        _pulseController.repeat(reverse: true);
      }
    } finally {
      _toggling = false;
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;
    final audioState = ref.read(audioServiceProvider);
    final audioService = ref.read(audioServiceProvider.notifier);
    if (audioState.isPlaying) {
      await audioService.stopPlayback();
    } else {
      await audioService.playRecording(_recordingPath!);
    }
  }

  void _feltGood() {
    HapticFeedback.lightImpact();
    ref
        .read(practiceSessionsProvider.notifier)
        .addSession(widget.scenarioId, true);
    context.go('/situations');
  }

  void _tryAgain() {
    ref
        .read(practiceSessionsProvider.notifier)
        .addSession(widget.scenarioId, false);
    ref.read(audioServiceProvider.notifier).stopPlayback();
    setState(() {
      _recordingPath = null;
      _isDone = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenario;
    final audioState = ref.watch(audioServiceProvider);
    final cs = Theme.of(context).colorScheme;

    if (scenario == null) {
      return Scaffold(
        appBar: AppBar(leadingWidth: 120, leading: _BackButton()),
        body: Center(
          child: Text('Situation not found.',
              style: GoogleFonts.figtree(color: cs.onSurface)),
        ),
      );
    }

    String statusText;
    if (audioState.isRecording) {
      statusText = 'Recording...';
    } else if (_isDone) {
      statusText = 'Done';
    } else {
      statusText = 'Tap to record';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // AppBar's leading slot defaults to a fixed 56dp (kToolbarHeight) —
        // plenty for a bare icon, but "Situations" wrapped character by
        // character inside it. Widen the slot instead of shrinking the text.
        leadingWidth: 120,
        leading: _BackButton(),
        title: Text(
          scenario.title,
          style: GoogleFonts.figtree(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                scenario.title,
                style: GoogleFonts.epilogue(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                scenario.context,
                style: GoogleFonts.figtree(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  height: 1.6,
                ),
              ),
              if (scenario.simulatedPrompt != null) ...[
                const SizedBox(height: 24),
                _CallTranscriptBlock(text: scenario.simulatedPrompt!),
              ],
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final scale =
                            audioState.isRecording ? _pulseAnimation.value : 1.0;
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: PressTrigger(
                        scaleTo: 0.94,
                        opacityTo: 0.85,
                        duration: const Duration(milliseconds: 120),
                        child: GestureDetector(
                          onTap: _toggleRecording,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: audioState.isRecording
                                  ? AppColors.primary.withValues(alpha: 0.88)
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                      alpha: audioState.isRecording ? 0.35 : 0.18),
                                  blurRadius: audioState.isRecording ? 28 : 16,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                audioState.isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_none,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        statusText,
                        key: ValueKey(statusText),
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          color: audioState.isRecording
                              ? AppColors.primary
                              : cs.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              if (_isDone && _recordingPath != null) ...[
                Center(
                  child: PressTrigger(
                    scaleTo: 0.93,
                    child: GestureDetector(
                      onTap: _playRecording,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.22),
                              blurRadius: 16,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            audioState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              if (_isDone) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppButton.primary(
                        label: 'Felt good',
                        onPressed: _feltGood,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.ghost(
                        label: 'Try again',
                        onPressed: _tryAgain,
                      ),
                    ),
                  ],
                ),
              ] else if (!audioState.isRecording) ...[
                const SizedBox(height: 80),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: () => context.go('/situations'),
      icon: Icon(Icons.arrow_back, size: 16,
          color: cs.onSurface.withValues(alpha: 0.4)),
      label: Text(
        'Situations',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.figtree(
          fontSize: 13,
          color: cs.onSurface.withValues(alpha: 0.4),
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurface.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _CallTranscriptBlock extends StatelessWidget {
  final String text;
  const _CallTranscriptBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.figtree(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: cs.onSurface.withValues(alpha: 0.6),
          height: 1.6,
        ),
      ),
    );
  }
}
