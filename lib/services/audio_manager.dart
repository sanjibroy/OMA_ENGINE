import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

/// Manages audio playback in the editor's play mode.
/// Uses absolute file paths via DeviceFileSource.
class AudioManager {
  AudioPlayer? _musicPlayer;
  final List<AudioPlayer> _sfxPool = [];

  Future<void> playMusic(String path) async {
    if (!File(path).existsSync()) return;
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.dispose();
      _musicPlayer = AudioPlayer();
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.play(DeviceFileSource(path));
    } catch (_) {}
  }

  Future<void> playSfx(String path) async {
    if (!File(path).existsSync()) return;
    try {
      final p = AudioPlayer();
      _sfxPool.add(p);
      await p.play(DeviceFileSource(path));
      p.onPlayerComplete.listen((_) {
        _sfxPool.remove(p);
        p.dispose();
      });
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.dispose();
    } catch (_) {}
    _musicPlayer = null;
  }

  Future<void> stopAll() async {
    await stopMusic();
    for (final p in List.of(_sfxPool)) {
      try {
        await p.stop();
        await p.dispose();
      } catch (_) {}
    }
    _sfxPool.clear();
  }

  /// Preview a single track (one-shot, not looping). Stops any current preview.
  Future<void> preview(String path) async {
    if (!File(path).existsSync()) return;
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.dispose();
      _musicPlayer = AudioPlayer();
      await _musicPlayer!.setReleaseMode(ReleaseMode.release);
      await _musicPlayer!.play(DeviceFileSource(path));
    } catch (_) {}
  }

  Future<void> stopPreview() => stopMusic();

  Future<void> dispose() => stopAll();
}
