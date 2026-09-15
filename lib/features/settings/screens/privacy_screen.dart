// PLACEHOLDER — needs legal review before publishing.
// The text below is a structured template only. Replace with actual legal text.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Icon(Icons.arrow_back,
                    size: 22, color: cs.onSurface),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Policy',
                      style: GoogleFonts.epilogue(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: [DATE]',
                      style: GoogleFonts.figtree(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _Section(
                      title: '1. What Data We Collect',
                      body:
                          'When you create an account, we collect:\n\n'
                          '• Account email address — used to authenticate you and display in your profile\n'
                          '• Display name — a name you choose, stored in your profile\n'
                          '• Community posts — text posts you submit to the community feed\n\n'
                          'Audio recordings you make during practice are stored locally on your device only and are never transmitted to our servers.',
                    ),
                    _Section(
                      title: '2. How We Use Your Data',
                      body:
                          'We use your data solely to operate the app:\n\n'
                          '• Your email is used for account authentication\n'
                          '• Your display name and community posts are shown to other users in the community feed\n'
                          '• We do not use your data for advertising or sell it to third parties',
                    ),
                    _Section(
                      title: '3. Data Storage',
                      body:
                          'Account data (email, display name, community posts, and likes) is stored securely using Supabase, a third-party database service. Supabase stores data on infrastructure in [REGION]. For Supabase\'s privacy practices, see supabase.com/privacy.',
                    ),
                    _Section(
                      title: '4. Audio Data',
                      body:
                          'Practice recordings are created and stored entirely on your device. They are never uploaded to Cadence servers or to any third party. You can delete them at any time by clearing app data or uninstalling the app.',
                    ),
                    _Section(
                      title: '5. Your Rights',
                      body:
                          'You have the right to:\n\n'
                          '• Access the data we hold about you\n'
                          '• Request correction of inaccurate data\n'
                          '• Request deletion of your account and associated data\n'
                          '• Withdraw consent at any time by signing out and deleting your account\n\n'
                          'To exercise these rights, contact us at the address below.',
                    ),
                    _Section(
                      title: '6. Data Retention',
                      body:
                          'We retain your account data for as long as your account is active. If you request account deletion, we will remove your personal data within 30 days, subject to any legal retention requirements.',
                    ),
                    _Section(
                      title: '7. Children\'s Privacy',
                      body:
                          'Cadence is not directed at children under 13. We do not knowingly collect personal data from children under 13. If you believe a child has provided us with personal data, please contact us.',
                    ),
                    _Section(
                      title: '8. Changes to This Policy',
                      body:
                          'We may update this policy from time to time. We will notify you of significant changes within the app. Continued use after changes constitutes acceptance of the updated policy.',
                    ),
                    _Section(
                      title: '9. Contact',
                      body:
                          'Questions about this policy or your data? Contact us at: [CONTACT EMAIL]',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.figtree(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.figtree(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
