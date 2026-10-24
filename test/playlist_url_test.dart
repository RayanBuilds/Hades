import 'package:flutter_test/flutter_test.dart';
import 'package:hades/core/utils/playlist_url.dart';

void main() {
  group('extractPlaylistId', () {
    test('reads the list parameter from music.youtube.com links', () {
      expect(
        extractPlaylistId(
          'https://music.youtube.com/playlist?list=PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
        ),
        'PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
      );
    });

    test('reads the list parameter from youtube.com links', () {
      expect(
        extractPlaylistId(
          'https://www.youtube.com/playlist?list=PLBCF2DAC6FFB574DE&si=abc',
        ),
        'PLBCF2DAC6FFB574DE',
      );
    });

    test('reads list parameters from shared youtu.be links', () {
      expect(
        extractPlaylistId(
          'https://youtu.be/dQw4w9WgXcQ?list=PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
        ),
        'PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
      );
    });

    test('strips the VL browse prefix', () {
      expect(
        extractPlaylistId(
          'https://music.youtube.com/browse/VLPLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
        ),
        'PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
      );
    });

    test('accepts bare ids with or without VL', () {
      expect(
        extractPlaylistId('PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI'),
        'PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
      );
      expect(
        extractPlaylistId('VLPLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI'),
        'PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
      );
    });

    test('rejects empty, short, and unrelated input', () {
      expect(extractPlaylistId(''), isNull);
      expect(extractPlaylistId('   '), isNull);
      expect(extractPlaylistId('PL123'), isNull);
      expect(extractPlaylistId('https://example.com/watch?v=abc'), isNull);
      expect(extractPlaylistId('not a playlist!!'), isNull);
    });
  });
}
