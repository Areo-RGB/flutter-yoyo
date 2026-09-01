/// Shared lightweight formatting helpers used by multiple screens/widgets.
///
/// Keeping these at the UI-core layer avoids duplicating the same `mm:ss`
/// arithmetic in [DistanceMeter] and [RemoteDistanceMeter].
String formatElapsedTimer(int totalElapsedMillis) {
  final minutes = totalElapsedMillis ~/ 60000;
  final seconds = (totalElapsedMillis % 60000) ~/ 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
