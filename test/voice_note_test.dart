import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/voice_note.dart';

void main() {
  test('VoiceNote date field defaults to null', () {
    final n = VoiceNote(title: 't', transcript: 'c');
    expect(n.date, isNull);
  });

  test('VoiceNote date field JSON round-trip', () {
    final date = DateTime(2026, 8, 28);
    final n = VoiceNote(title: 'Shutdown', transcript: 'Prep', date: date);
    final restored = VoiceNote.fromJson(n.toJson());
    expect(restored.date, date);
    expect(restored.title, 'Shutdown');
    expect(restored.transcript, 'Prep');
  });

  test('VoiceNote copyWith can set and clear date', () {
    final n = VoiceNote(title: 't', transcript: 'c');
    final withDate = n.copyWith(date: DateTime(2026, 1, 1));
    expect(withDate.date, DateTime(2026, 1, 1));
    final cleared = withDate.copyWith(clearDate: true);
    expect(cleared.date, isNull);
  });
}
