class _UmaOkaPreset {
  final int returnPoint;
  final List<double> rankBonus;
  final String label;

  const _UmaOkaPreset({
    required this.returnPoint,
    required this.rankBonus,
    required this.label,
  });
}

class UmaOkaRule {
  static const _fourPlayer = _UmaOkaPreset(
    returnPoint: 30000,
    rankBonus: [50.0, 10.0, -10.0, -30.0],
    label: '30000点返し / ウマ 10-30 / オカ 20',
  );

  // 3麻はフリー寄りのMリーグ風として 35000持ち40000返し + 順位点 40/0/-40。
  static const _threePlayer = _UmaOkaPreset(
    returnPoint: 40000,
    rankBonus: [40.0, 0.0, -40.0],
    label: '40000点返し / 順位点 40-0--40（3麻）',
  );

  static _UmaOkaPreset _preset(int playerCount) {
    return playerCount == 3 ? _threePlayer : _fourPlayer;
  }

  static double result({
    required int finalPoints,
    required int rank,
    int playerCount = 4,
  }) {
    final preset = _preset(playerCount);
    if (rank < 1 || rank > preset.rankBonus.length) {
      throw ArgumentError('rank out of range for $playerCount-player mode: $rank');
    }
    return ((finalPoints - preset.returnPoint) / 1000.0) +
        preset.rankBonus[rank - 1];
  }

  static String format(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}';
  }

  static String labelForPlayerCount(int playerCount) {
    return _preset(playerCount).label;
  }
}
