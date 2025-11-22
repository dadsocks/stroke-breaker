class PuttResult {
  const PuttResult({
    required this.x,
    required this.y,
    required this.putts,
  });

  /// Horizontal offset in feet (+right, -left).
  final double x;

  /// Vertical offset in feet (+long, -short).
  final double y;

  /// Number of putts taken from this start (1, 2, or 3+).
  final int putts;
}
