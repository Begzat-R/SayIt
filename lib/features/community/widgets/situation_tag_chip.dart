import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../situations/data/scenarios.dart';
import '../../situations/models/scenario.dart';

/// Small chip showing which Situation a "What did you try today?" post
/// relates to. Renders nothing if [situationTag] doesn't match a known
/// scenario (or is null), so it silently degrades for a generic post.
class SituationTagChip extends StatelessWidget {
  final String? situationTag;
  const SituationTagChip({super.key, required this.situationTag});

  @override
  Widget build(BuildContext context) {
    if (situationTag == null) return const SizedBox.shrink();
    Scenario? scenario;
    for (final s in kScenarios) {
      if (s.id == situationTag) {
        scenario = s;
        break;
      }
    }
    if (scenario == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        scenario.title,
        style: GoogleFonts.figtree(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
