import '../model/models.dart';

class ScorePreview {
  final String title;
  final List<String> lines;

  ScorePreview({required this.title, required this.lines});
}

class ScoreCalc {
  static List<int> fuCandidates(RuleConfig rules) {
    final list = <int>[20];
    if (rules.keepFu25) {
      list.add(25);
    }
    for (var fu = 30; fu <= 110; fu += 10) {
      list.add(fu);
    }
    return list;
  }

  static int _roundUpTo100(int v) {
    return ((v + 99) ~/ 100) * 100;
  }

  static int _normalizeFu(int fu, RuleConfig rules) {
    if (rules.keepFu25 && fu == 25) {
      return 25;
    }
    final rounded = ((fu + 9) ~/ 10) * 10;
    if (rounded < 20 || rounded > 110) {
      throw ArgumentError('符が範囲外です: $fu');
    }
    return rounded;
  }

  static (_LimitType, int) _calcBasePoints(int han, int fu, RuleConfig rules) {
    if (han >= 13) {
      if (rules.kazoeAsYakuman) {
        return (_LimitType.yakuman, 8000);
      }
      return (_LimitType.sanbaiman, 6000);
    }
    if (han >= 11) {
      return (_LimitType.sanbaiman, 6000);
    }
    if (han >= 8) {
      return (_LimitType.baiman, 4000);
    }
    if (han >= 6) {
      return (_LimitType.haneman, 3000);
    }
    if (han >= 5) {
      return (_LimitType.mangan, 2000);
    }
    if (han == 4 && fu >= 40) {
      return (_LimitType.mangan, 2000);
    }
    if (han == 3 && fu >= 70) {
      return (_LimitType.mangan, 2000);
    }

    final base = fu * (1 << (han + 2));
    if (base >= 2000) {
      return (_LimitType.mangan, 2000);
    }
    if (rules.enableKiriageMangan && base == 1920) {
      return (_LimitType.mangan, 2000);
    }
    return (_LimitType.none, base);
  }

  static ScorePreview preview({
    required RoomState state,
    required Seat winnerSeat,
    required AgariMethod method,
    required int han,
    required int fu,
    Seat? ronLoserSeat,
  }) {
    final winnerIsDealer = winnerSeat == state.dealerSeat;
    final useTsumoLossless = state.playerCount == 3;
    final rules = state.rules;
    final fuKey = _normalizeFu(fu, rules);
    final (limitType, basePoints) = _calcBasePoints(han, fuKey, rules);

    final honba = state.honba;
    final kyotaku = state.kyotaku;

    final lines = <String>[];
    final title = '$han翻$fuKey符 / ${method == AgariMethod.ron ? 'ロン' : 'ツモ'}';

    if (method == AgariMethod.ron) {
      if (ronLoserSeat == null) {
        lines.add('放銃者を選択してください');
        return ScorePreview(title: title, lines: lines);
      }

      final basePay =
          winnerIsDealer ? _roundUpTo100(basePoints * 6) : _roundUpTo100(basePoints * 4);
      final pay = basePay + honba * 300;

      lines.add('${seatToJp(ronLoserSeat)} -> ${seatToJp(winnerSeat)} : $pay 点');
    } else {
      if (winnerIsDealer) {
        final each = _roundUpTo100(basePoints * (useTsumoLossless ? 3 : 2)) + honba * 100;
        lines.add('全員 -> ${seatToJp(winnerSeat)} : 各 $each 点');
      } else {
        final fromDealer = _roundUpTo100(basePoints * 2) + honba * 100;
        final fromChild =
            _roundUpTo100(basePoints * (useTsumoLossless ? 2 : 1)) + honba * 100;
        lines.add('${seatToJp(state.dealerSeat)}(親) -> ${seatToJp(winnerSeat)} : $fromDealer 点');
        lines.add('子 -> ${seatToJp(winnerSeat)} : 各 $fromChild 点');
      }
    }

    if (kyotaku > 0) {
      lines.add('供託: $kyotaku本 = ${kyotaku * 1000} 点（和了者へ）');
    }

    if (honba > 0) {
      lines.add('本場: $honba（ロン:+${honba * 300} / ツモ:+${honba * 100}ずつ）');
    }

    lines.add('区分: ${_limitToJp(limitType)}');

    return ScorePreview(title: title, lines: lines);
  }
}

enum _LimitType { none, mangan, haneman, baiman, sanbaiman, yakuman }

String _limitToJp(_LimitType t) {
  switch (t) {
    case _LimitType.none:
      return '通常';
    case _LimitType.mangan:
      return '満貫';
    case _LimitType.haneman:
      return '跳満';
    case _LimitType.baiman:
      return '倍満';
    case _LimitType.sanbaiman:
      return '三倍満';
    case _LimitType.yakuman:
      return '役満';
  }
}
