import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/motivation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://opwcsijnfypcmgqjobuf.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wd2NzaWpuZnlwY21ncWpvYnVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0MDk0MDksImV4cCI6MjEwNDk4NTQwOX0.a0xzw8AFv1b2qDThGPTCZ48ST18mux-YgXMeXeAevvU',
  );

  await MotivationService.initialize();
  final launchedFromNotification =
      await MotivationService.launchedFromNotification();
  // Fire-and-forget: rotates today's message if the previous reminder's
  // fire time has already passed. See MotivationService docs.
  unawaited(MotivationService.refreshIfNeeded());

  runApp(
    ProviderScope(
      overrides: [
        launchedFromNotificationProvider.overrideWithValue(
          launchedFromNotification,
        ),
      ],
      child: const CadenceApp(),
    ),
  );
}
