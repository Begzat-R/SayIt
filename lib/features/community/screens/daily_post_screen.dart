import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../situations/data/scenarios.dart';
import '../providers/community_provider.dart';

/// Distinct compose flow for the daily "What did you try today?" prompt —
/// a short text field plus an optional Situation tag, as opposed to the
/// generic new-post sheet on the Community feed.
class DailyPostScreen extends ConsumerStatefulWidget {
  const DailyPostScreen({super.key});

  @override
  ConsumerState<DailyPostScreen> createState() => _DailyPostScreenState();
}

class _DailyPostScreenState extends ConsumerState<DailyPostScreen> {
  final _ctrl = TextEditingController();
  String? _situationId;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    final ok = await ref
        .read(newPostProvider.notifier)
        .submit(body, situationTag: _situationId);
    if (ok && mounted) {
      HapticFeedback.lightImpact();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = ref.watch(newPostProvider) is AsyncLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          // Keyboard opening shrinks the available body height
          // (resizeToAvoidBottomInset, on by default); without a
          // scrollable ancestor the fixed content + Share button below
          // could no longer fit and overflowed. Scrolling lets the whole
          // column ride up so the button stays reachable instead.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back, size: 22, color: cs.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'What did you try today?',
                style: GoogleFonts.epilogue(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A quick note on a moment you practiced speaking today.',
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                maxLength: 500,
                maxLines: 4,
                minLines: 3,
                autofocus: true,
                style: GoogleFonts.figtree(
                    fontSize: 15, color: cs.onSurface, height: 1.6),
                decoration: InputDecoration(
                  hintText: 'e.g. Ordered coffee without freezing up…',
                  hintStyle: GoogleFonts.figtree(
                      fontSize: 15, color: cs.onSurface.withValues(alpha: 0.35)),
                  counterStyle: GoogleFonts.figtree(
                      fontSize: 11, color: cs.onSurface.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: cs.onSurface.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'TAG A SITUATION (OPTIONAL)',
                style: GoogleFonts.figtree(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.35),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kScenarios.map((s) {
                  final selected = _situationId == s.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _situationId = selected ? null : s.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : cs.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.title,
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Share',
                          style: GoogleFonts.figtree(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
