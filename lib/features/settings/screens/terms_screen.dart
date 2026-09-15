// PLACEHOLDER — needs legal review before publishing.
// The text below is a structured template only. Replace with actual legal text.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
                      'Terms of Service',
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
                      title: '1. Acceptance of Terms',
                      body:
                          'By downloading or using Cadence, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.',
                    ),
                    _Section(
                      title: '2. Description of Service',
                      body:
                          'Cadence is a speech practice application designed to help people who stutter rehearse real-world speaking situations. The app provides recorded practice sessions, a community forum, and progress tracking.',
                    ),
                    _Section(
                      title: '3. User Accounts',
                      body:
                          'You may use core features without an account. Creating an account allows you to participate in the community, save your display name, and access posts. You are responsible for maintaining the security of your account credentials.',
                    ),
                    _Section(
                      title: '4. User Content',
                      body:
                          'Community posts you create remain your property. By posting, you grant us a non-exclusive licence to display your content within the app. You agree not to post content that is harmful, abusive, or violates applicable laws.',
                    ),
                    _Section(
                      title: '5. Audio Recordings',
                      body:
                          'Practice recordings are stored locally on your device and are never uploaded to our servers. You control your recordings at all times.',
                    ),
                    _Section(
                      title: '6. Prohibited Use',
                      body:
                          'You agree not to misuse the service, including but not limited to: attempting to gain unauthorised access, distributing harmful content, or using the app for commercial solicitation without prior written consent.',
                    ),
                    _Section(
                      title: '7. Disclaimer',
                      body:
                          'Cadence is not a medical or therapeutic service. It does not replace professional speech-language therapy. Use of the app does not constitute a therapeutic relationship.',
                    ),
                    _Section(
                      title: '8. Limitation of Liability',
                      body:
                          'To the maximum extent permitted by law, Cadence and its developers shall not be liable for any indirect, incidental, or consequential damages arising from your use of the app.',
                    ),
                    _Section(
                      title: '9. Changes to Terms',
                      body:
                          'We may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the new terms.',
                    ),
                    _Section(
                      title: '10. Contact',
                      body:
                          'Questions about these terms? Contact us at: [CONTACT EMAIL]',
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
