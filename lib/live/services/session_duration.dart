Duration finalizedSessionDuration({
  required DateTime startedAt,
  required DateTime endedAt,
  required Duration sampledElapsed,
}) {
  final wallClockElapsed = endedAt.difference(startedAt);
  if (wallClockElapsed <= Duration.zero) return sampledElapsed;

  // The one-second UI ticker can be suspended while iOS opens the Watch app
  // or backgrounds Flutter. Preserve its value when it is newer, otherwise
  // use the authoritative session timestamps at completion.
  return wallClockElapsed > sampledElapsed ? wallClockElapsed : sampledElapsed;
}
