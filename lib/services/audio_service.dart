import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// How long we wait for the native recorder to respond to stop() before
/// giving up on it. record's AudioRecorder serializes every call (start,
/// stop, dispose, everything) through one internal Semaphore that's only
/// released once the platform call it's guarding actually returns — so if
/// a single native stop() call hangs (observed on-device: the mic session
/// stayed active indefinitely per `dumpsys audio`, confirmed by nothing —
/// not a retry, not even a keyboard-focus-triggered activation — being
/// able to un-stick it), every future call on that same instance,
/// including the next start(), deadlocks forever waiting for a semaphore
/// permit that will never be released. There is no cancel-a-stuck-Future
/// escape hatch from outside the package, so the only way back to a
/// working state is to stop using that instance.
const _stopTimeout = Duration(seconds: 5);

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
  AudioRecorder _recorder = AudioRecorder();
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
    try {
      final path = await _recorder.stop().timeout(_stopTimeout);
      state = state.copyWith(isRecording: false, lastRecordingPath: path);
      return path;
    } on TimeoutException {
      // Don't await dispose() on the stuck instance — it goes through the
      // same jammed semaphore as stop() and would hang forever too. Let it
      // dangle and swap in a fresh recorder so the next startRecording()
      // actually works instead of hanging on the very first call.
      _recorder.dispose().ignore();
      _recorder = AudioRecorder();
      state = state.copyWith(isRecording: false);
      return null;
    }
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
