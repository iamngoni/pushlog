export function didTakeLead(
  previousCount: number,
  currentCount: number,
  friendCount: number,
): boolean {
  return (
    currentCount > previousCount &&
    previousCount <= friendCount &&
    currentCount > friendCount
  );
}

export function repsToRetakeLead(
  leaderCount: number,
  trailingCount: number,
): number {
  return Math.max(leaderCount - trailingCount + 1, 1);
}
