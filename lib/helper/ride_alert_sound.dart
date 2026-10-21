import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Sonnerie d'une nouvelle demande de course: joue en boucle pendant
/// [duration] (15 s par défaut), puis s'arrête toute seule.
/// Elle s'arrête aussi si le chauffeur accepte/refuse ou si la course est annulée.
class RideAlertSound {
  static AudioPlayer? _player;
  static Timer? _timer;

  static Future<void> play({Duration duration = const Duration(seconds: 15)}) async {
    await stop();
    try {
      final AudioPlayer player = AudioPlayer();
      _player = player;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('notification.wav'));
      _timer = Timer(duration, stop);
    } catch (_) {
      _player = null;
    }
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final AudioPlayer? player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
  }
}
