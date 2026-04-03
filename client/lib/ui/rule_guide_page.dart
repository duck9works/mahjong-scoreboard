import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RuleGuidePage extends StatelessWidget {
  static const List<int> _pointTableFus = [20, 25, 30, 40, 50, 60, 70, 80];
  static const List<int> _pointTableHans = [1, 2, 3, 4];

  const RuleGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ルール・手引き'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '役一覧'),
              Tab(text: '翻数/符計算'),
              Tab(text: '点数表'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildYakuTab(context),
            _buildHanFuTab(context),
            _buildPointTableTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildYakuTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _section(
          context,
          title: '役一覧（門前 / 鳴き）',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '一般的なリーチ麻雀の代表的な役です。ローカルルールで変わる場合があります。',
              ),
              const SizedBox(height: 8),
              _yakuTable(_basicYakuRows),
              const SizedBox(height: 10),
              const Text(
                '役満',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              _yakuTable(_yakumanRows),
              const SizedBox(height: 8),
              const Text('※ ドラ・赤ドラ・裏ドラは役ではなく、飜数加算です。'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHanFuTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _section(
          context,
          title: '翻数計算の考え方',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideLine('翻数 = 役の翻数合計 + ドラ + 赤ドラ + 裏ドラ（リーチ時）。'),
              _GuideLine('門前限定役は鳴くと成立しません。'),
              _GuideLine('食い下がりありの役は、鳴くと1翻下がるものがあります。'),
              _GuideLine('本アプリの点数入力では、最終的な翻数と符数を入力します。'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          context,
          title: '符計算の基本',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideLine('基本符は 20符。'),
              _GuideLine('ツモ和了は +2符（ただし平和ツモは20符扱い）。'),
              _GuideLine('門前ロンは +10符。'),
              _GuideLine('待ち形（辺張・嵌張・単騎）は +2符。'),
              _GuideLine('雀頭が役牌（白發中・場風・自風）なら +2符。'),
              _GuideLine('面子の符（刻子/槓子）は下の表を参照。'),
              _GuideLine('七対子は 25符固定。'),
              _GuideLine('最終符は 10符単位に切り上げ（25符固定を除く）。'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          context,
          title: '刻子・槓子の符',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('面子')),
                DataColumn(label: Text('中張牌')),
                DataColumn(label: Text('么九牌/字牌')),
              ],
              rows: const [
                DataRow(
                  cells: [
                    DataCell(Text('明刻')),
                    DataCell(Text('2符')),
                    DataCell(Text('4符')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('暗刻')),
                    DataCell(Text('4符')),
                    DataCell(Text('8符')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('明槓')),
                    DataCell(Text('8符')),
                    DataCell(Text('16符')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('暗槓')),
                    DataCell(Text('16符')),
                    DataCell(Text('32符')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _section(
          context,
          title: '牌イメージで見る符の付き方',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('待ち形（+2符）', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              _TileExample(
                label: '辺張待ち',
                desc: '1m 2m の形で 3m 待ち',
                tiles: ['1m', '2m', '3m'],
                emphasizeLast: true,
              ),
              SizedBox(height: 6),
              _TileExample(
                label: '嵌張待ち',
                desc: '2m 4m の形で 3m 待ち',
                tiles: ['2m', '3m', '4m'],
                emphasizeMiddle: true,
              ),
              SizedBox(height: 6),
              _TileExample(
                label: '単騎待ち',
                desc: '雀頭の 7p 待ち',
                tiles: ['7p', '7p'],
                emphasizeLast: true,
              ),
              SizedBox(height: 12),
              Text('面子の例', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              _TileExample(
                label: '中張牌の明刻',
                desc: '4s 4s 4s（+2符）',
                tiles: ['4s', '4s', '4s'],
              ),
              SizedBox(height: 6),
              _TileExample(
                label: '么九牌の暗刻',
                desc: '東 東 東（+8符）',
                tiles: ['東', '東', '東'],
              ),
              SizedBox(height: 6),
              _TileExample(
                label: '中張牌の明槓',
                desc: '6p 6p 6p 6p（+8符）',
                tiles: ['6p', '6p', '6p', '6p'],
              ),
              SizedBox(height: 6),
              _TileExample(
                label: '么九牌の暗槓',
                desc: '白 白 白 白（+32符）',
                tiles: ['白', '白', '白', '白'],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          context,
          title: '注意事項',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideLine('本アプリでは切り上げ満貫/数え役満の ON/OFF をルーム作成時に設定できます。'),
              _GuideLine('点数計算は和了入力（翻・符・和了方法）をもとに処理されます。'),
              _GuideLine('本ページの内容は学習用ガイドです。運用ルールがある場合はそちらを優先してください。'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointTableTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _section(
          context,
          title: '点数表（本場・供託なし）',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('20/25/30/40/50/60/70/80符 × 1〜4翻'),
              const SizedBox(height: 4),
              Text(
                '※ 切り上げ満貫 ON 前提（4翻30符、3翻60符は満貫扱い）',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 8),
              _pointTable(
                title: '子ロン',
                kind: _PointTableKind.childRon,
              ),
              const SizedBox(height: 10),
              _pointTable(
                title: '子ツモ',
                subtitle: '表記: 子の支払い / 親の支払い',
                kind: _PointTableKind.childTsumo,
              ),
              const SizedBox(height: 10),
              _pointTable(
                title: '親ロン',
                kind: _PointTableKind.parentRon,
              ),
              const SizedBox(height: 10),
              _pointTable(
                title: '親ツモ',
                subtitle: '表記: ◯◯オール',
                kind: _PointTableKind.parentTsumo,
              ),
              const SizedBox(height: 6),
              Text(
                '※ 成立しない組み合わせ（20符ロン、20符1翻、25符1翻など）は「-」表示',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _yakuTable(List<_YakuRow> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('役名')),
          DataColumn(label: Text('門前')),
          DataColumn(label: Text('鳴き')),
          DataColumn(label: Text('備考')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.name)),
                  DataCell(Text(row.menzenHan)),
                  DataCell(Text(row.openHan)),
                  DataCell(Text(row.note)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _pointTable({
    required String title,
    required _PointTableKind kind,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12)),
        ],
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: [
              const DataColumn(label: Text('符\\翻')),
              ..._pointTableHans.map((han) => DataColumn(label: Text('$han翻'))),
            ],
            rows: _pointTableFus.map((fu) {
              return DataRow(
                cells: [
                  DataCell(Text('$fu符')),
                  ..._pointTableHans.map((han) {
                    return DataCell(
                      Text(
                        _pointCellValue(fu: fu, han: han, kind: kind),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _pointCellValue({
    required int fu,
    required int han,
    required _PointTableKind kind,
  }) {
    if (!_isCombinationValid(fu: fu, han: han, kind: kind)) {
      return '-';
    }

    final base = _calcBasePoints(han: han, fu: fu);
    switch (kind) {
      case _PointTableKind.childRon:
        return '${_roundUpTo100(base * 4)}';
      case _PointTableKind.childTsumo:
        return '${_roundUpTo100(base)}/${_roundUpTo100(base * 2)}';
      case _PointTableKind.parentRon:
        return '${_roundUpTo100(base * 6)}';
      case _PointTableKind.parentTsumo:
        return '${_roundUpTo100(base * 2)}オール';
    }
  }

  bool _isCombinationValid({
    required int fu,
    required int han,
    required _PointTableKind kind,
  }) {
    final isRon =
        kind == _PointTableKind.childRon || kind == _PointTableKind.parentRon;
    if (fu == 20 && isRon) {
      return false;
    }
    if (fu == 20 && han == 1) {
      return false;
    }
    if (fu == 25 && han == 1) {
      return false;
    }
    return true;
  }

  int _roundUpTo100(int value) => ((value + 99) ~/ 100) * 100;

  int _calcBasePoints({required int han, required int fu}) {
    if (han >= 5) {
      return 2000;
    }
    if (han == 4 && fu >= 40) {
      return 2000;
    }
    if (han == 3 && fu >= 70) {
      return 2000;
    }

    final base = fu * (1 << (han + 2));
    if (base >= 2000) {
      return 2000;
    }

    // 切り上げ満貫 ON のとき、1920点は満貫扱い。
    if (base == 1920) {
      return 2000;
    }
    return base;
  }
}

enum _PointTableKind { childRon, childTsumo, parentRon, parentTsumo }

class _GuideLine extends StatelessWidget {
  final String text;

  const _GuideLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('・$text'),
    );
  }
}

class _TileExample extends StatelessWidget {
  final String label;
  final String desc;
  final List<String> tiles;
  final bool emphasizeLast;
  final bool emphasizeMiddle;

  const _TileExample({
    required this.label,
    required this.desc,
    required this.tiles,
    this.emphasizeLast = false,
    this.emphasizeMiddle = false,
  });

  @override
  Widget build(BuildContext context) {
    final middleIndex = tiles.length ~/ 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: [
              for (var index = 0; index < tiles.length; index++)
                _TileBadge(
                  text: tiles[index],
                  emphasize: (emphasizeLast && index == tiles.length - 1) ||
                      (emphasizeMiddle && index == middleIndex),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TileBadge extends StatelessWidget {
  final String text;
  final bool emphasize;

  const _TileBadge({
    required this.text,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = emphasize
        ? Theme.of(context).colorScheme.secondary
        : const Color(0xFFB8B8B8);
    final assetPath = _tileAssetPath(text);

    return Container(
      width: 38,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: emphasize ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: SvgPicture.asset(
          assetPath,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color:
                    emphasize ? Theme.of(context).colorScheme.secondary : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tileAssetPath(String tile) {
    switch (tile) {
      case '1m':
        return 'assets/tiles/1m.svg';
      case '2m':
        return 'assets/tiles/2m.svg';
      case '3m':
        return 'assets/tiles/3m.svg';
      case '4m':
        return 'assets/tiles/4m.svg';
      case '4s':
        return 'assets/tiles/4s.svg';
      case '6p':
        return 'assets/tiles/6p.svg';
      case '7p':
        return 'assets/tiles/7p.svg';
      case '東':
        return 'assets/tiles/east.svg';
      case '白':
        return 'assets/tiles/white.svg';
      default:
        return 'assets/tiles/1m.svg';
    }
  }
}

class _YakuRow {
  final String name;
  final String menzenHan;
  final String openHan;
  final String note;

  const _YakuRow({
    required this.name,
    required this.menzenHan,
    required this.openHan,
    this.note = '',
  });
}

const List<_YakuRow> _basicYakuRows = [
  _YakuRow(name: 'リーチ', menzenHan: '1', openHan: '-', note: '門前限定'),
  _YakuRow(name: '一発', menzenHan: '1', openHan: '-', note: '門前限定'),
  _YakuRow(name: '門前清自摸和', menzenHan: '1', openHan: '-', note: '門前限定'),
  _YakuRow(name: '断么九', menzenHan: '1', openHan: '1'),
  _YakuRow(name: '平和', menzenHan: '1', openHan: '-', note: '門前限定'),
  _YakuRow(name: '一盃口', menzenHan: '1', openHan: '-', note: '門前限定'),
  _YakuRow(name: '役牌（白/發/中）', menzenHan: '1', openHan: '1'),
  _YakuRow(name: '自風牌', menzenHan: '1', openHan: '1'),
  _YakuRow(name: '場風牌', menzenHan: '1', openHan: '1'),
  _YakuRow(name: '海底摸月/河底撈魚', menzenHan: '1', openHan: '1'),
  _YakuRow(name: '嶺上開花', menzenHan: '1', openHan: '1'),
  _YakuRow(name: '槍槓', menzenHan: '1', openHan: '1'),
  _YakuRow(name: 'ダブル立直', menzenHan: '2', openHan: '-', note: '門前限定'),
  _YakuRow(name: '七対子', menzenHan: '2', openHan: '-', note: '25符固定'),
  _YakuRow(name: '対々和', menzenHan: '2', openHan: '2'),
  _YakuRow(name: '三暗刻', menzenHan: '2', openHan: '2'),
  _YakuRow(name: '三色同刻', menzenHan: '2', openHan: '2'),
  _YakuRow(name: '三槓子', menzenHan: '2', openHan: '2'),
  _YakuRow(name: '小三元', menzenHan: '2', openHan: '2'),
  _YakuRow(name: '混老頭', menzenHan: '2', openHan: '2'),
  _YakuRow(name: '三色同順', menzenHan: '2', openHan: '1'),
  _YakuRow(name: '一気通貫', menzenHan: '2', openHan: '1'),
  _YakuRow(name: '全帯么九', menzenHan: '2', openHan: '1'),
  _YakuRow(name: '二盃口', menzenHan: '3', openHan: '-', note: '門前限定'),
  _YakuRow(name: '純全帯么九', menzenHan: '3', openHan: '2'),
  _YakuRow(name: '混一色', menzenHan: '3', openHan: '2'),
  _YakuRow(name: '清一色', menzenHan: '6', openHan: '5'),
];

const List<_YakuRow> _yakumanRows = [
  _YakuRow(name: '国士無双', menzenHan: '役満', openHan: '-', note: '門前限定'),
  _YakuRow(name: '四暗刻', menzenHan: '役満', openHan: '-', note: '門前限定'),
  _YakuRow(name: '大三元', menzenHan: '役満', openHan: '役満'),
  _YakuRow(name: '字一色', menzenHan: '役満', openHan: '役満'),
  _YakuRow(name: '小四喜', menzenHan: '役満', openHan: '役満'),
  _YakuRow(name: '大四喜', menzenHan: 'ダブル役満', openHan: 'ダブル役満'),
  _YakuRow(name: '緑一色', menzenHan: '役満', openHan: '役満'),
  _YakuRow(name: '清老頭', menzenHan: '役満', openHan: '役満'),
  _YakuRow(name: '四槓子', menzenHan: '役満', openHan: '役満'),
  _YakuRow(name: '九蓮宝燈', menzenHan: '役満', openHan: '-', note: '門前限定'),
  _YakuRow(name: '天和', menzenHan: '役満', openHan: '-', note: '親のみ'),
  _YakuRow(name: '地和', menzenHan: '役満', openHan: '-', note: '子のみ'),
];
