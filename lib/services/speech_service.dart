import 'package:speech_to_text/speech_to_text.dart' as stt;
import './app_logger.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => log.error('speech', 'Speech error: ${val.errorMsg}'),
        onStatus: (val) {
          log.info('speech', 'Speech status: $val');
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      log.error('speech', 'Speech init failed (expected on Windows/desktop fallback): $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> startListening({
    required Function(String text) onResult,
    Function(double soundLevel)? onSoundLevel,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    _isListening = true;
    try {
      await _speech.listen(
        onResult: (val) {
          onResult(val.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        onSoundLevelChange: onSoundLevel,
      );
    } catch (e) {
      log.error('speech', 'Speech listen exception: $e');
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    try {
      await _speech.stop();
    } catch (e) {
      log.error('speech', 'Speech stop error: $e');
    }
  }
}
