import 'package:intl/intl.dart';

/// "just now", "5m ago", "3h ago" or "2d ago".
String formatAge(Duration age) {
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}

/// The host of a source URL without a leading "www.", e.g. "finance.yahoo.com".
String sourceLabel(String source) {
  final host = Uri.tryParse(source)?.host ?? '';
  if (host.isEmpty) return source;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// A short, user-facing reason for a failed load.
String describeLoadError(Object error) {
  var text = error.toString();
  while (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  final status = RegExp(r'^Status code: (\d+)$').firstMatch(text);
  if (status != null) return 'Server returned ${status.group(1)}';
  if (text == 'Timed out') return 'Request timed out';
  if (text.startsWith('Failed to parse')) {
    return 'Unexpected response from the server';
  }
  return 'Could not reach the server';
}

/// When a price was recorded: the time today, otherwise the date and time.
String formatPriceTime(DateTime time, DateTime now) {
  final local = time.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final sameDay =
      !local.isBefore(today) &&
      local.isBefore(today.add(const Duration(days: 1)));
  return sameDay
      ? DateFormat('HH:mm').format(local)
      : DateFormat('MMM d, HH:mm').format(local);
}

/// Where a ticker's data came from and how current it is.
///
/// [lastPoint] is the time of the newest price, which can be old even when
/// the data was just fetched (for example when a market is closed), while
/// [fetchedAt] is when the app last received data.
String freshnessSummary({
  required List<String> sources,
  required DateTime lastPoint,
  required DateTime fetchedAt,
  required DateTime now,
  String? error,
}) {
  final labels = sources.map(sourceLabel).toSet().join(', ');
  return [
    if (labels.isNotEmpty) 'Source: $labels',
    'Last price: ${formatPriceTime(lastPoint, now)}',
    'Updated ${formatAge(now.difference(fetchedAt))}',
    if (error != null) 'Reload failed: $error',
  ].join('\n');
}
