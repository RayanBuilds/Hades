/// Extracts a YouTube Music playlist id from a shared link or raw id.
///
/// Accepts `music.youtube.com/playlist?list=...`, `youtube.com/playlist?...`,
/// `youtu.be/...?list=...`, `/browse/VL...` links, and bare `PL...` / `VL...`
/// ids. Returns ids without the `VL` browse prefix; callers add it themselves.
String? extractPlaylistId(String input) {
  var value = input.trim();
  if (value.isEmpty) return null;

  if (value.contains('://') || value.startsWith('www.')) {
    final uri = Uri.tryParse(
      value.startsWith('www.') ? 'https://$value' : value,
    );
    if (uri == null) return null;
    final fromQuery = uri.queryParameters['list'];
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return _normalize(fromQuery);
    }
    final segments = uri.pathSegments;
    final browseIndex = segments.indexOf('browse');
    if (browseIndex >= 0 && browseIndex + 1 < segments.length) {
      return _normalize(segments[browseIndex + 1]);
    }
    if (segments.isNotEmpty && segments.last.startsWith('VL')) {
      return _normalize(segments.last);
    }
    return null;
  }

  return _normalize(value);
}

String? _normalize(String id) {
  var value = id.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('VL')) value = value.substring(2);
  if (value.length < 10) return null;
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) return null;
  return value;
}
