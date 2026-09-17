import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../providers/block_provider.dart';

/// Block / Report overflow menu for a user, shared by the profile screen
/// and DM thread header.
class UserActionsMenu extends ConsumerWidget {
  final String targetUserId;
  final String targetDisplayName;
  final VoidCallback? onBlocked;

  const UserActionsMenu({
    super.key,
    required this.targetUserId,
    required this.targetDisplayName,
    this.onBlocked,
  });

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref, bool isBlocked) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBlocked ? 'Unblock $targetDisplayName?' : 'Block $targetDisplayName?'),
        content: Text(
          isBlocked
              ? 'They will be able to message and find you again.'
              : 'They won\'t be able to message you, follow you, or find your profile in search — and you won\'t see theirs either.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isBlocked ? 'Unblock' : 'Block',
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(blockNotifierProvider.notifier)
        .setBlocked(targetUserId, !isBlocked);
    if (ok && !isBlocked) onBlocked?.call();
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report $targetDisplayName'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What\'s going on?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Submit')),
        ],
      ),
    );
    if (submitted != true) return;
    final ok = await ref
        .read(reportNotifierProvider.notifier)
        .reportUser(targetUserId, reasonCtrl.text);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlockedAsync = ref.watch(amIBlockingProvider(targetUserId));
    final isBlocked = isBlockedAsync.value ?? false;
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: cs.onSurface.withValues(alpha: 0.6)),
      onSelected: (value) {
        if (value == 'block') _confirmBlock(context, ref, isBlocked);
        if (value == 'report') _report(context, ref);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'block',
          child: Text(isBlocked ? 'Unblock' : 'Block',
              style: GoogleFonts.figtree(fontSize: 14)),
        ),
        PopupMenuItem(
          value: 'report',
          child: Text('Report', style: GoogleFonts.figtree(fontSize: 14)),
        ),
      ],
    );
  }
}
