import 'package:flutter/material.dart';

import '../gateway/api_client.dart';
import '../gateway/record_gateway.dart';
import '../gateway/user_gateway.dart';
import '../model/models.dart';
import '../util/uma_oka.dart';
import 'user_manage_page.dart';

enum _RecordFilter {
  tonpu,
  hanchan,
}

enum _PlayerCountFilter {
  fourPlayer,
  threePlayer,
}

enum _SensitiveViewLevel {
  hidden,
  dateTimeVisible,
  allVisible,
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _api = ApiClient();
  late final _recordsGateway = RecordGateway(_api);
  late final _usersGateway = UserGateway(_api);

  bool _loading = false;
  bool _mutating = false;
  String? _error;
  _RecordFilter _filter = _RecordFilter.tonpu;
  _PlayerCountFilter _playerCountFilter = _PlayerCountFilter.fourPlayer;
  _SensitiveViewLevel _sensitiveViewLevel = _SensitiveViewLevel.hidden;
  int _secretTapCount = 0;
  DateTime? _lastSecretTapAt;

  List<MatchRecord> _records = [];
  List<UserProfile> _users = [];
  Set<String> _hiddenUserIds = <String>{};
  Map<String, String> _userNames = {};

  bool get _canShowDateTime =>
      _sensitiveViewLevel.index >= _SensitiveViewLevel.dateTimeVisible.index;
  bool get _canShowTotalResult =>
      _sensitiveViewLevel == _SensitiveViewLevel.allVisible;

  void _onTitleTapped() {
    final now = DateTime.now();
    if (_lastSecretTapAt == null ||
        now.difference(_lastSecretTapAt!) > const Duration(seconds: 3)) {
      _secretTapCount = 0;
    }
    _lastSecretTapAt = now;
    _secretTapCount += 1;

    if (_secretTapCount < 5) {
      return;
    }

    _secretTapCount = 0;
    setState(() {
      if (_sensitiveViewLevel == _SensitiveViewLevel.hidden) {
        _sensitiveViewLevel = _SensitiveViewLevel.dateTimeVisible;
      } else if (_sensitiveViewLevel == _SensitiveViewLevel.dateTimeVisible) {
        _sensitiveViewLevel = _SensitiveViewLevel.allVisible;
      } else {
        _sensitiveViewLevel = _SensitiveViewLevel.hidden;
      }
    });

    if (_sensitiveViewLevel == _SensitiveViewLevel.dateTimeVisible) {
      _toast('日時表示と編集/削除をONにしました');
      return;
    }
    if (_sensitiveViewLevel == _SensitiveViewLevel.allVisible) {
      _toast('総合ポイント表示をONにしました');
      return;
    }
    _toast('日時表示・編集/削除・総合ポイント表示をOFFにしました');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final recordsFuture = _recordsGateway.getRecords();
      final usersFuture = _usersGateway.getUsers();
      final records = await recordsFuture;
      final users = await usersFuture;

      final nameMap = <String, String>{};
      for (final user in users) {
        nameMap[user.userId] = user.displayName;
      }

      final hiddenUserIds =
          users.where((u) => u.isHidden).map((u) => u.userId).toSet();

      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _users = users;
        _hiddenUserIds = hiddenUserIds;
        _userNames = nameMap;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<MatchRecord> _visibleRecords() {
    final filteredByGameType = switch (_filter) {
      _RecordFilter.tonpu =>
        _records.where((x) => x.finalState.gameType == GameType.tonpu).toList(),
      _RecordFilter.hanchan => _records
          .where((x) => x.finalState.gameType == GameType.hanchan)
          .toList(),
    };

    final filteredByPlayerCount = switch (_playerCountFilter) {
      _PlayerCountFilter.fourPlayer =>
        filteredByGameType.where((x) => x.playerCount == 4).toList(),
      _PlayerCountFilter.threePlayer =>
        filteredByGameType.where((x) => x.playerCount == 3).toList(),
    };

    return filteredByPlayerCount
        .where(
          (record) =>
              record.participants.any((p) => !_isHiddenUserId(p.userId)),
        )
        .toList();
  }

  bool _isHiddenUserId(String? userId) {
    return userId != null &&
        userId.isNotEmpty &&
        _hiddenUserIds.contains(userId);
  }

  List<MatchParticipant> _sortedParticipants(MatchRecord record) {
    final ranked = [...record.participants];
    ranked.sort((a, b) {
      final pointComp = b.finalPoints.compareTo(a.finalPoints);
      if (pointComp != 0) {
        return pointComp;
      }
      return a.seat.index.compareTo(b.seat.index);
    });
    return ranked;
  }

  List<_PlayerStat> _buildStats(List<MatchRecord> records) {
    final statByUser = <String, _PlayerStatBuilder>{};
    final rateTrackingStartAt = _estimateRateTrackingStart(records);

    for (final record in records) {
      final ranked = _sortedParticipants(record);
      final logSummary = _collectLogSummary(record.logs);
      final rateTrackable = _isRateTrackableRecord(
        record,
        rateTrackingStartAt,
      );

      for (var index = 0; index < ranked.length; index++) {
        final participant = ranked[index];
        final userId = participant.userId;
        if (userId == null || userId.isEmpty || _isHiddenUserId(userId)) {
          continue;
        }

        final stat = statByUser.putIfAbsent(
          userId,
          () => _PlayerStatBuilder(
            userId: userId,
            displayName: _userNames[userId] ?? userId,
          ),
        );

        stat.games += 1;
        stat.totalHands += logSummary.totalHands;
        stat.totalPoints += participant.finalPoints;
        if (participant.finalPoints > stat.bestScore) {
          stat.bestScore = participant.finalPoints;
        }
        stat.rankCounts[index] += 1;
        stat.totalResult += UmaOkaRule.result(
          finalPoints: participant.finalPoints,
          rank: index + 1,
          playerCount: record.playerCount,
        );
        if (index == ranked.length - 1) {
          stat.lastCount += 1;
        }

        final seat = participant.seat;
        if (rateTrackable) {
          stat.rateGames += 1;
          stat.rateHands += logSummary.totalHands;
          stat.riichiCount += logSummary.riichiBySeat[seat] ?? 0;
          stat.furoCount += logSummary.furoBySeat[seat] ?? 0;
          stat.rateAgariCount += logSummary.agariBySeat[seat] ?? 0;
          stat.rateDealInCount += logSummary.dealInBySeat[seat] ?? 0;
        }
        stat.agariCount += logSummary.agariBySeat[seat] ?? 0;
        stat.dealInCount += logSummary.dealInBySeat[seat] ?? 0;
        stat.winPointTotal += logSummary.winPointBySeat[seat] ?? 0;
        stat.dealInPointTotal += logSummary.dealInPointBySeat[seat] ?? 0;
      }
    }

    final stats = statByUser.values.map((x) => x.build()).toList()
      ..sort((a, b) {
        final avgRankComp = a.averageRank.compareTo(b.averageRank);
        if (avgRankComp != 0) {
          return avgRankComp;
        }
        if (_canShowTotalResult) {
          final resultComp = b.totalResult.compareTo(a.totalResult);
          if (resultComp != 0) {
            return resultComp;
          }
        }
        final gameComp = b.games.compareTo(a.games);
        if (gameComp != 0) {
          return gameComp;
        }
        return a.displayName.compareTo(b.displayName);
      });

    return stats;
  }

  DateTime? _estimateRateTrackingStart(List<MatchRecord> records) {
    DateTime? earliest;
    for (final record in records) {
      final hasFuroLog = record.logs.any((log) => log.type == RoomLogType.furo);
      if (!hasFuroLog) {
        continue;
      }
      final endedAt = record.endedAt;
      if (earliest == null || endedAt.isBefore(earliest)) {
        earliest = endedAt;
      }
    }
    return earliest;
  }

  bool _isRateTrackableRecord(
    MatchRecord record,
    DateTime? rateTrackingStartAt,
  ) {
    if (record.roomId.toUpperCase() == 'MANUAL') {
      return false;
    }

    final hasFuroLog = record.logs.any((log) => log.type == RoomLogType.furo);
    if (hasFuroLog) {
      return true;
    }

    if (rateTrackingStartAt == null) {
      return false;
    }

    return !record.endedAt.isBefore(rateTrackingStartAt);
  }

  List<UserProfile> _selectableUsers() {
    return _users.where((u) => !_hiddenUserIds.contains(u.userId)).toList();
  }

  _MatchLogSummary _collectLogSummary(List<RoomLogEntry> logs) {
    var totalHands = 0;
    final riichiBySeat = <Seat, int>{};
    final furoBySeat = <Seat, int>{};
    final agariBySeat = <Seat, int>{};
    final dealInBySeat = <Seat, int>{};
    final winPointBySeat = <Seat, int>{};
    final dealInPointBySeat = <Seat, int>{};

    void increment(Map<Seat, int> source, Seat seat, [int delta = 1]) {
      source[seat] = (source[seat] ?? 0) + delta;
    }

    for (final log in logs) {
      if (log.type == RoomLogType.agari || log.type == RoomLogType.ryukyoku) {
        totalHands += 1;
      }

      if (log.type == RoomLogType.riichi) {
        final seat = log.actorSeat ?? _seatFromMessagePrefix(log.message);
        if (seat != null) {
          increment(riichiBySeat, seat);
        }
      }

      if (log.type == RoomLogType.furo) {
        final seat = log.actorSeat ?? _seatFromMessagePrefix(log.message);
        if (seat != null) {
          increment(furoBySeat, seat);
        }
      }

      if (log.type == RoomLogType.agari) {
        final winnerSeat =
            log.winnerSeat ?? _seatFromMessagePrefix(log.message);
        if (winnerSeat != null) {
          increment(agariBySeat, winnerSeat);
          if (log.pointValue != null) {
            increment(winPointBySeat, winnerSeat, log.pointValue!);
          }
        }

        if (log.loserSeat != null) {
          increment(dealInBySeat, log.loserSeat!);
          if (log.dealInPointValue != null) {
            increment(dealInPointBySeat, log.loserSeat!, log.dealInPointValue!);
          }
        }
      }
    }

    return _MatchLogSummary(
      totalHands: totalHands,
      riichiBySeat: riichiBySeat,
      furoBySeat: furoBySeat,
      agariBySeat: agariBySeat,
      dealInBySeat: dealInBySeat,
      winPointBySeat: winPointBySeat,
      dealInPointBySeat: dealInPointBySeat,
    );
  }

  Seat? _seatFromMessagePrefix(String message) {
    final trimmed = message.trimLeft();
    for (final seat in Seat.values) {
      if (trimmed.startsWith(seatToJp(seat))) {
        return seat;
      }
    }
    return null;
  }

  String _nameForParticipant(MatchParticipant participant) {
    final userId = participant.userId;
    if (userId == null || userId.isEmpty || _isHiddenUserId(userId)) {
      return '${seatToJp(participant.seat)}席';
    }
    return _userNames[userId] ?? userId;
  }

  Color _resultColor(double value) {
    return value >= 0
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.error;
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String pad2(int x) => x.toString().padLeft(2, '0');
    return '${local.year}/${pad2(local.month)}/${pad2(local.day)} ${pad2(local.hour)}:${pad2(local.minute)}';
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _umaOkaLabelForVisibleRecords(List<MatchRecord> visibleRecords) {
    final contains3 = visibleRecords.any((x) => x.playerCount == 3);
    final contains4 = visibleRecords.any((x) => x.playerCount == 4);
    if (contains3 && contains4) {
      return '4麻: ${UmaOkaRule.labelForPlayerCount(4)} / 3麻: ${UmaOkaRule.labelForPlayerCount(3)}';
    }
    if (contains3) {
      return UmaOkaRule.labelForPlayerCount(3);
    }
    return UmaOkaRule.labelForPlayerCount(4);
  }

  Future<void> _createManualRecord() async {
    if (_loading || _mutating) {
      return;
    }

    final draft = await _showManualRecordDialog();
    if (draft == null) {
      return;
    }

    setState(() {
      _mutating = true;
    });

    try {
      await _recordsGateway.createManualRecord(
        gameType: draft.gameType,
        participants: draft.participants,
        startedAt: draft.startedAt,
        endedAt: draft.endedAt,
      );
      _toast('手動で対局結果を追加しました');
      await _load();
    } catch (e) {
      _toast('手動記録の追加に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _mutating = false;
        });
      }
    }
  }

  Future<void> _editRecord(MatchRecord record) async {
    if (_loading || _mutating || !_canShowDateTime) {
      return;
    }

    final draft = await _showManualRecordDialog(initialRecord: record);
    if (draft == null) {
      return;
    }

    setState(() {
      _mutating = true;
    });

    try {
      await _recordsGateway.updateRecord(
        recordId: record.matchId,
        gameType: draft.gameType,
        participants: draft.participants,
        startedAt: draft.startedAt,
        endedAt: draft.endedAt,
      );
      _toast('記録を更新しました');
      await _load();
    } catch (e) {
      _toast('記録更新に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _mutating = false;
        });
      }
    }
  }

  Future<void> _deleteRecord(MatchRecord record) async {
    if (_loading || _mutating || !_canShowDateTime) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('対局記録の削除'),
        content: const Text('この記録を削除しますか？この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _mutating = true;
    });

    try {
      await _recordsGateway.deleteRecord(record.matchId);
      _toast('記録を削除しました');
      await _load();
    } catch (e) {
      _toast('記録削除に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _mutating = false;
        });
      }
    }
  }

  Future<_ManualRecordDraft?> _showManualRecordDialog({
    MatchRecord? initialRecord,
  }) async {
    final isEditing = initialRecord != null;
    final selectableUsers = _selectableUsers();
    final selectableUserIds = selectableUsers.map((u) => u.userId).toSet();
    String? normalizeSelectedUserId(String? userId) {
      if (userId == null || userId.isEmpty) {
        return null;
      }
      if (selectableUserIds.contains(userId)) {
        return userId;
      }
      return null;
    }

    final participantsBySeat = <Seat, MatchParticipant>{
      for (final participant
          in initialRecord?.participants ?? const <MatchParticipant>[])
        participant.seat: participant,
    };
    var playerCount = normalizePlayerCount(initialRecord?.playerCount ?? 4);
    List<Seat> activeSeats() => seatsForPlayerCount(playerCount);
    int defaultInitialPoints() => playerCount == 3 ? 35000 : 25000;
    final initialEndedAtLocal =
        (initialRecord?.endedAt ?? DateTime.now()).toLocal();
    final pointControllers = <Seat, TextEditingController>{
      for (final seat in Seat.values)
        seat: TextEditingController(
          text:
              '${participantsBySeat[seat]?.finalPoints ?? defaultInitialPoints()}',
        ),
    };
    void onPlayerCountChanged(int nextPlayerCount) {
      if (!isEditing) {
        final oldDefault = defaultInitialPoints();
        final nextDefault = nextPlayerCount == 3 ? 35000 : 25000;
        for (final seat in seatsForPlayerCount(nextPlayerCount)) {
          final controller = pointControllers[seat]!;
          final text = controller.text.trim();
          final parsed = int.tryParse(text);
          if (text.isEmpty || parsed == oldDefault) {
            controller.text = '$nextDefault';
          }
        }
      }
      playerCount = nextPlayerCount;
    }

    final userIdBySeat = <Seat, String?>{
      for (final seat in Seat.values)
        seat: normalizeSelectedUserId(participantsBySeat[seat]?.userId)
    };
    var gameType = initialRecord?.finalState.gameType ?? GameType.tonpu;
    var selectedDate = initialEndedAtLocal;
    var selectedTime = TimeOfDay(
      hour: initialEndedAtLocal.hour,
      minute: initialEndedAtLocal.minute,
    );
    String? errorText;

    try {
      return await showDialog<_ManualRecordDraft>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(isEditing ? '成績を編集' : '手動で対局結果を追加'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(
                            value: 4,
                            label: Text('4麻'),
                          ),
                          ButtonSegment<int>(
                            value: 3,
                            label: Text('3麻'),
                          ),
                        ],
                        selected: {playerCount},
                        onSelectionChanged: (selection) {
                          setDialogState(() {
                            onPlayerCountChanged(selection.first);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<GameType>(
                        segments: const [
                          ButtonSegment<GameType>(
                            value: GameType.tonpu,
                            label: Text('東風戦'),
                          ),
                          ButtonSegment<GameType>(
                            value: GameType.hanchan,
                            label: Text('半荘戦'),
                          ),
                        ],
                        selected: {gameType},
                        onSelectionChanged: (selection) {
                          setDialogState(() {
                            gameType = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (picked == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          '日付: ${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: dialogContext,
                            initialTime: selectedTime,
                          );
                          if (picked == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedTime = picked;
                          });
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          '時刻: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...activeSeats().map((seat) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                seatToJp(seat),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String?>(
                                value: userIdBySeat[seat],
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'プレイヤー'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('未設定'),
                                  ),
                                  ...selectableUsers.map(
                                    (user) => DropdownMenuItem<String?>(
                                      value: user.userId,
                                      child: Text(
                                        user.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    userIdBySeat[seat] = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: pointControllers[seat],
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: '点数'),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('キャンセル'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final participants = <ManualRecordParticipantInput>[];
                      for (final seat in activeSeats()) {
                        final pointsText = pointControllers[seat]!.text.trim();
                        final points = int.tryParse(pointsText);
                        if (points == null) {
                          setDialogState(() {
                            errorText = '${seatToJp(seat)} の点数が不正です';
                          });
                          return;
                        }

                        participants.add(
                          ManualRecordParticipantInput(
                            seat: seat,
                            userId: userIdBySeat[seat],
                            finalPoints: points,
                          ),
                        );
                      }

                      Navigator.of(dialogContext).pop(
                        _ManualRecordDraft(
                          gameType: gameType,
                          participants: participants,
                          startedAt: initialRecord?.startedAt,
                          endedAt: DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          ),
                        ),
                      );
                    },
                    child: Text(isEditing ? '更新' : '追加'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      for (final controller in pointControllers.values) {
        controller.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecords = _visibleRecords();
    final stats = _buildStats(visibleRecords);
    final maxRank =
        visibleRecords.any((record) => record.playerCount == 4) ? 4 : 3;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTitleTapped,
          child: const Text('戦績一覧'),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserManagePage(userGateway: _usersGateway),
                ),
              );
              if (!mounted) {
                return;
              }
              await _load();
            },
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'ユーザー管理',
          ),
          IconButton(
            onPressed: (_loading || _mutating) ? null : _createManualRecord,
            icon: const Icon(Icons.add),
            tooltip: '手動記録を追加',
          ),
          IconButton(
            onPressed: (_loading || _mutating) ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SegmentedButton<_RecordFilter>(
              segments: const [
                ButtonSegment(value: _RecordFilter.tonpu, label: Text('東風戦')),
                ButtonSegment(value: _RecordFilter.hanchan, label: Text('半荘戦')),
              ],
              selected: {_filter},
              onSelectionChanged: (_loading || _mutating)
                  ? null
                  : (selection) {
                      setState(() {
                        _filter = selection.first;
                      });
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<_PlayerCountFilter>(
              segments: const [
                ButtonSegment(
                    value: _PlayerCountFilter.fourPlayer, label: Text('4麻')),
                ButtonSegment(
                    value: _PlayerCountFilter.threePlayer, label: Text('3麻')),
              ],
              selected: {_playerCountFilter},
              onSelectionChanged: (_loading || _mutating)
                  ? null
                  : (selection) {
                      setState(() {
                        _playerCountFilter = selection.first;
                      });
                    },
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '戦績の読み込みに失敗しました: $_error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('対局数', '${visibleRecords.length}'),
                      _chip('集計人数', '${stats.length}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _chip('ウマオカ', _umaOkaLabelForVisibleRecords(visibleRecords)),
                  const SizedBox(height: 10),
                  if (stats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        '対局データがありません',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    _buildPlayerStatsMatrix(stats, maxRank),
                  const SizedBox(height: 14),
                  const Text(
                    '対局履歴',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  if (visibleRecords.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        '記録はまだありません',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...visibleRecords.map((record) {
                      final ranked = _sortedParticipants(record);
                      final canManageRecord =
                          _canShowDateTime && !_loading && !_mutating;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  if (_canShowDateTime)
                                    Expanded(
                                      child: Text(
                                        _formatDate(record.endedAt),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  _chip('形式',
                                      gameTypeToJp(record.finalState.gameType)),
                                  _chip('人数',
                                      playerCountToJp(record.playerCount)),
                                  if (_canShowDateTime)
                                    IconButton(
                                      onPressed: canManageRecord
                                          ? () => _editRecord(record)
                                          : null,
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: '編集',
                                    ),
                                  if (_canShowDateTime)
                                    IconButton(
                                      onPressed: canManageRecord
                                          ? () => _deleteRecord(record)
                                          : null,
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: '削除',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (var index = 0;
                                  index < ranked.length;
                                  index++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        child: Text('${index + 1}位'),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _nameForParticipant(ranked[index]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text('${ranked[index].finalPoints}'),
                                      const SizedBox(width: 10),
                                      Text(
                                        UmaOkaRule.format(
                                          UmaOkaRule.result(
                                            finalPoints:
                                                ranked[index].finalPoints,
                                            rank: index + 1,
                                            playerCount: record.playerCount,
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: _resultColor(
                                            UmaOkaRule.result(
                                              finalPoints:
                                                  ranked[index].finalPoints,
                                              rank: index + 1,
                                              playerCount: record.playerCount,
                                            ),
                                          ),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatsMatrix(List<_PlayerStat> stats, int maxRank) {
    final metricRows = <_StatMetric>[
      _StatMetric(label: '試合数', value: (stat) => '${stat.games}'),
      _StatMetric(label: '総局数', value: (stat) => '${stat.totalHands}'),
      if (_canShowTotalResult)
        _StatMetric(
          label: 'ポイント',
          value: (stat) => UmaOkaRule.format(stat.totalResult),
          color: (stat) => _resultColor(stat.totalResult),
        ),
      _StatMetric(
          label: '平着', value: (stat) => stat.averageRank.toStringAsFixed(2)),
      _StatMetric(label: '1位', value: (stat) => '${stat.rankCounts[0]}'),
      _StatMetric(label: '2位', value: (stat) => '${stat.rankCounts[1]}'),
      _StatMetric(label: '3位', value: (stat) => '${stat.rankCounts[2]}'),
      if (maxRank >= 4)
        _StatMetric(label: '4位', value: (stat) => '${stat.rankCounts[3]}'),
      _StatMetric(label: 'トップ率', value: (stat) => _formatRate(stat.topRate)),
      _StatMetric(
          label: '連対率', value: (stat) => _formatRateOptional(stat.top2Rate)),
      _StatMetric(
          label: 'ラス回避率', value: (stat) => _formatRate(stat.avoidLastRate)),
      _StatMetric(label: 'ベストスコア', value: (stat) => '${stat.bestScore}'),
      _StatMetric(
          label: '平均打点',
          value: (stat) => _formatOptional(stat.averageWinPoint)),
      _StatMetric(
          label: '副露率', value: (stat) => _formatRateOptional(stat.furoRate)),
      _StatMetric(
          label: 'リーチ率', value: (stat) => _formatRateOptional(stat.riichiRate)),
      _StatMetric(
          label: 'アガリ率', value: (stat) => _formatRateOptional(stat.agariRate)),
      _StatMetric(
          label: '放銃率', value: (stat) => _formatRateOptional(stat.dealInRate)),
      _StatMetric(
          label: '放銃平均打点',
          value: (stat) => _formatOptional(stat.averageDealInPoint)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: [
              const DataColumn(label: Text('選手名')),
              ...stats.map(
                (stat) => DataColumn(
                  label: Text(
                    stat.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            rows: metricRows
                .map(
                  (metric) => DataRow(
                    cells: [
                      DataCell(
                        Text(
                          metric.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      ...stats.map(
                        (stat) => DataCell(
                          Text(
                            metric.value(stat),
                            style: TextStyle(
                              fontWeight: metric.color == null
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: metric.color?.call(stat),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  String _formatRate(double value) => value.toStringAsFixed(2);
  String _formatRateOptional(double? value) =>
      value == null ? '-' : value.toStringAsFixed(2);

  String _formatOptional(double? value) {
    if (value == null) {
      return '-';
    }
    return value.toStringAsFixed(2);
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _ManualRecordDraft {
  final GameType gameType;
  final List<ManualRecordParticipantInput> participants;
  final DateTime? startedAt;
  final DateTime endedAt;

  const _ManualRecordDraft({
    required this.gameType,
    required this.participants,
    required this.startedAt,
    required this.endedAt,
  });
}

class _PlayerStat {
  final String userId;
  final String displayName;
  final int games;
  final int totalHands;
  final int rateGames;
  final int rateHands;
  final List<int> rankCounts;
  final int totalPoints;
  final double totalResult;
  final double averageRank;
  final int bestScore;
  final int riichiCount;
  final int furoCount;
  final int rateAgariCount;
  final int rateDealInCount;
  final int agariCount;
  final int dealInCount;
  final int lastCount;
  final int winPointTotal;
  final int dealInPointTotal;

  const _PlayerStat({
    required this.userId,
    required this.displayName,
    required this.games,
    required this.totalHands,
    required this.rateGames,
    required this.rateHands,
    required this.rankCounts,
    required this.totalPoints,
    required this.totalResult,
    required this.averageRank,
    required this.bestScore,
    required this.riichiCount,
    required this.furoCount,
    required this.rateAgariCount,
    required this.rateDealInCount,
    required this.agariCount,
    required this.dealInCount,
    required this.lastCount,
    required this.winPointTotal,
    required this.dealInPointTotal,
  });

  double get topRate => games == 0 ? 0 : rankCounts[0] / games;
  double? get top2Rate =>
      games == 0 ? null : (rankCounts[0] + rankCounts[1]) / games;
  double get avoidLastRate => games == 0 ? 0 : (games - lastCount) / games;
  double? get furoRate => rateHands == 0 ? null : furoCount / rateHands;
  double? get riichiRate => rateHands == 0 ? null : riichiCount / rateHands;
  double? get agariRate => rateHands == 0 ? null : rateAgariCount / rateHands;
  double? get dealInRate => rateHands == 0 ? null : rateDealInCount / rateHands;
  double? get averageWinPoint =>
      agariCount == 0 ? null : winPointTotal / agariCount;
  double? get averageDealInPoint =>
      dealInCount == 0 ? null : dealInPointTotal / dealInCount;
}

class _PlayerStatBuilder {
  final String userId;
  final String displayName;
  int games = 0;
  int totalHands = 0;
  int rateGames = 0;
  int rateHands = 0;
  int totalPoints = 0;
  double totalResult = 0.0;
  int bestScore = -0x3fffffff;
  int riichiCount = 0;
  int furoCount = 0;
  int rateAgariCount = 0;
  int rateDealInCount = 0;
  int agariCount = 0;
  int dealInCount = 0;
  int lastCount = 0;
  int winPointTotal = 0;
  int dealInPointTotal = 0;
  final List<int> rankCounts = [0, 0, 0, 0];

  _PlayerStatBuilder({
    required this.userId,
    required this.displayName,
  });

  _PlayerStat build() {
    final weightedRankTotal = rankCounts[0] +
        rankCounts[1] * 2 +
        rankCounts[2] * 3 +
        rankCounts[3] * 4;
    final averageRank = games == 0 ? 0.0 : weightedRankTotal / games;

    return _PlayerStat(
      userId: userId,
      displayName: displayName,
      games: games,
      totalHands: totalHands,
      rateGames: rateGames,
      rateHands: rateHands,
      rankCounts: List<int>.from(rankCounts),
      totalPoints: totalPoints,
      totalResult: totalResult,
      averageRank: averageRank,
      bestScore: bestScore,
      riichiCount: riichiCount,
      furoCount: furoCount,
      rateAgariCount: rateAgariCount,
      rateDealInCount: rateDealInCount,
      agariCount: agariCount,
      dealInCount: dealInCount,
      lastCount: lastCount,
      winPointTotal: winPointTotal,
      dealInPointTotal: dealInPointTotal,
    );
  }
}

class _MatchLogSummary {
  final int totalHands;
  final Map<Seat, int> riichiBySeat;
  final Map<Seat, int> furoBySeat;
  final Map<Seat, int> agariBySeat;
  final Map<Seat, int> dealInBySeat;
  final Map<Seat, int> winPointBySeat;
  final Map<Seat, int> dealInPointBySeat;

  const _MatchLogSummary({
    required this.totalHands,
    required this.riichiBySeat,
    required this.furoBySeat,
    required this.agariBySeat,
    required this.dealInBySeat,
    required this.winPointBySeat,
    required this.dealInPointBySeat,
  });
}

class _StatMetric {
  final String label;
  final String Function(_PlayerStat stat) value;
  final Color Function(_PlayerStat stat)? color;

  const _StatMetric({
    required this.label,
    required this.value,
    this.color,
  });
}
