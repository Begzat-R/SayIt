import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://opwcsijnfypcmgqjobuf.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wd2NzaWpuZnlwY21ncWpvYnVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0MDk0MDksImV4cCI6MjEwNDk4NTQwOX0.a0xzw8AFv1b2qDThGPTCZ48ST18mux-YgXMeXeAevvU',
  );

  runApp(const ProviderScope(child: CadenceApp()));
}
