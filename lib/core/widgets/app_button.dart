import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import 'press_trigger.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final _ButtonVariant _variant;

  // ignore: prefer_initializing_formals
  const AppButton._({
    required this.label,
    required this.onPressed,
    required _ButtonVariant variant,
    super.key,
  }) : _variant = variant;

  factory AppButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      AppButton._(
        key: key,
        label: label,
        onPressed: onPressed,
        variant: _ButtonVariant.primary,
      );

  factory AppButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      AppButton._(
        key: key,
        label: label,
        onPressed: onPressed,
        variant: _ButtonVariant.secondary,
      );

  factory AppButton.ghost({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      AppButton._(
        key: key,
        label: label,
        onPressed: onPressed,
        variant: _ButtonVariant.ghost,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = GoogleFonts.figtree(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    Widget button;
    switch (_variant) {
      case _ButtonVariant.primary:
        button = ElevatedButton(
          onPressed: onPressed,
          child: Text(label, style: labelStyle),
        );
      case _ButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurface,
            side: BorderSide(color: cs.onSurface.withValues(alpha: 0.3), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: const Size(double.infinity, 52),
          ),
          child: Text(label, style: labelStyle),
        );
      case _ButtonVariant.ghost:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.onSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Text(
            label,
            style: labelStyle.copyWith(color: AppColors.onSurfaceMuted(context)),
          ),
        );
    }

    return PressTrigger(
      enabled: onPressed != null,
      child: button,
    );
  }
}

enum _ButtonVariant { primary, secondary, ghost }
