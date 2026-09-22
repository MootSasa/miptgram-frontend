import 'package:flutter_test/flutter_test.dart';
import 'package:theaver/services/cache_service.dart';

void main() {
  group('CacheService Tests', () {
    test('categorizeFile accurately categorizes file extensions', () {
      // Photos
      expect(CacheService.categorizeFile('/path/to/image.jpg'), equals('photos'));
      expect(CacheService.categorizeFile('photo.png'), equals('photos'));
      expect(CacheService.categorizeFile('avatar.WEBP'), equals('photos'));
      expect(CacheService.categorizeFile('c:/temp/animation.gif'), equals('photos'));
      expect(CacheService.categorizeFile('picture.heic'), equals('photos'));

      // Videos
      expect(CacheService.categorizeFile('/movies/clip.mp4'), equals('videos'));
      expect(CacheService.categorizeFile('round_video.mov'), equals('videos'));
      expect(CacheService.categorizeFile('stream.webm'), equals('videos'));
      expect(CacheService.categorizeFile('recording.mkv'), equals('videos'));

      // Audio
      expect(CacheService.categorizeFile('/audio/voice.m4a'), equals('audio'));
      expect(CacheService.categorizeFile('song.mp3'), equals('audio'));
      expect(CacheService.categorizeFile('voice_note.ogg'), equals('audio'));
      expect(CacheService.categorizeFile('sound.opus'), equals('audio'));
      expect(CacheService.categorizeFile('recording.wav'), equals('audio'));

      // Files
      expect(CacheService.categorizeFile('/docs/document.pdf'), equals('files'));
      expect(CacheService.categorizeFile('archive.zip'), equals('files'));
      expect(CacheService.categorizeFile('notes.txt'), equals('files'));
      expect(CacheService.categorizeFile('sheet.xlsx'), equals('files'));

      // Other
      expect(CacheService.categorizeFile('unknown.dat'), equals('other'));
      expect(CacheService.categorizeFile('binary.bin'), equals('other'));
      expect(CacheService.categorizeFile('no_extension'), equals('other'));
    });

    test('formatBytes properly formats various byte amounts', () {
      expect(CacheService.formatBytes(0), equals('0 B'));
      expect(CacheService.formatBytes(-100), equals('0 B'));
      expect(CacheService.formatBytes(512), equals('512 B'));
      expect(CacheService.formatBytes(1024), equals('1.0 KB'));
      expect(CacheService.formatBytes(1024 * 1024), equals('1.0 MB'));
      expect(CacheService.formatBytes(1024 * 1024 * 50), equals('50 MB'));
      expect(CacheService.formatBytes(1024 * 1024 * 1024), equals('1.0 GB'));
      expect(CacheService.formatBytes(1024 * 1024 * 1024 * 3), equals('3.0 GB'));
    });

    test('CacheBreakdown.empty creates default empty stats', () {
      final breakdown = CacheBreakdown.empty();
      expect(breakdown.totalBytes, equals(0));
      expect(breakdown.totalHuman, equals('0 B'));
      expect(breakdown.photos.sizeBytes, equals(0));
      expect(breakdown.videos.sizeBytes, equals(0));
      expect(breakdown.audio.sizeBytes, equals(0));
      expect(breakdown.files.sizeBytes, equals(0));
      expect(breakdown.other.sizeBytes, equals(0));
      expect(breakdown.categories.length, equals(5));
    });
  });
}
