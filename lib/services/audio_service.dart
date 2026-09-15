import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class AudioServiceState {
  final bool isRecording;
  final bool isPlaying;
  final String? lastRecordingPath;

  const AudioServiceState({
    this.isRecording = false,
    this.isPlaying = false,
    this.lastRecordingPath,
  });

  AudioServiceState copyWith({
    bool? isRecording,
    bool? isPlaying,
    String? lastRecordingPath,
  }) {
    return AudioServiceState(
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      lastRecordingPath: lastRecordingPath ?? this.lastRecordingPath,
    );
  }
}

class AudioService extends StateNotifier<AudioServiceState> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  AudioService() : super(const AudioServiceState()) {
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(isPlaying: false);
      }
    });
  }

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${const Uuid().v4()}.m4a';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    state = state.copyWith(isRecording: true, lastRecordingPath: path);
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    state = state.copyWith(isRecording: false, lastRecordingPath: path);
    return path;
  }

  Future<void> playRecording(String path) async {
    if (!File(path).existsSync()) return;

    await _player.setFilePath(path);
    state = state.copyWith(isPlaying: true);
    await _player.play();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    state = state.copyWith(isPlaying: false);
  }

  @override
  void dispose() {
    _recorder.dispose().ignore();
    _player.dispose();
    super.dispose();
  }
}

final audioServiceProvider =
    StateNotifierProvider<AudioService, AudioServiceState>((ref) {
  return AudioService();
});
