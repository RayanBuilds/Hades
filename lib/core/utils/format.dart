String formatDuration(Duration? duration, {bool forceHours = false}) {
  if (duration == null) return '';
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0 || forceHours) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

String formatCount(int? count) {
  if (count == null || count < 0) return '';
  if (count >= 1000000000) {
    return '${(count / 1000000000).toStringAsFixed(1)}B';
  }
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return '$count';
}

String greetingForHour(int hour) {
  if (hour < 5) return 'Still awake?';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

/// Removes common YouTube Music suffixes before querying lyrics providers.
String cleanTrackTitle(String title) {
  var value = title;
  const patterns = [
    r'\s*[\(\[]\s*(official\s*)?(music\s*)?video\s*[\)\]]',
    r'\s*[\(\[]\s*(official\s*)?(lyric\s*)?video\s*[\)\]]',
    r'\s*[\(\[]\s*official\s*(audio|visualizer)\s*[\)\]]',
    r'\s*[\(\[]\s*lyrics?\s*[\)\]]',
    r'\s*[\(\[]\s*audio\s*[\)\]]',
    r'\s*[\(\[]\s*hd\s*[\)\]]',
    r'\s*[\(\[]\s*explicit\s*[\)\]]',
    r'\s*[\(\[]\s*visualizer\s*[\)\]]',
  ];
  for (final pattern in patterns) {
    value = value.replaceAll(RegExp(pattern, caseSensitive: false), '');
  }
  return value.trim();
}

String cleanArtistName(String artist) {
  var value = artist;
  if (value.toLowerCase().endsWith(' - topic')) {
    value = value.substring(0, value.length - 8);
  }
  return value.trim();
}

bool fuzzyTitleMatch(String a, String b) {
  String normal(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  final left = normal(a);
  final right = normal(b);
  if (left.isEmpty || right.isEmpty) return false;
  return left == right || left.contains(right) || right.contains(left);
}
