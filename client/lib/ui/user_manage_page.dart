import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../gateway/user_gateway.dart';
import '../model/models.dart';
import '../util/riichi_voice.dart';
import 'records_page.dart';
import 'widgets/icon_crop_dialog.dart';

class UserManagePage extends StatefulWidget {
  final UserGateway userGateway;

  const UserManagePage({
    super.key,
    required this.userGateway,
  });

  @override
  State<UserManagePage> createState() => _UserManagePageState();
}

class _UserManagePageState extends State<UserManagePage> {
  static const int _maxIconBytes = 2 * 1024 * 1024;
  static const int _maxSourceIconBytes = 8 * 1024 * 1024;

  final _voicePlayer = RiichiVoicePlayer();

  bool _busy = false;
  bool _adminMode = false;
  int _secretTapCount = 0;
  DateTime? _lastSecretTapAt;
  List<UserProfile> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _voicePlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
    });

    try {
      final users = await widget.userGateway.getUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
      });
    } catch (e) {
      _toast('読み込みに失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

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
      _adminMode = !_adminMode;
    });
    _toast(_adminMode ? '管理者モードをONにしました' : '管理者モードをOFFにしました');
  }

  Future<void> _toggleUserHidden(UserProfile user) async {
    if (_busy) {
      return;
    }

    final succeeded = await _updateUser(user, isHidden: !user.isHidden);
    if (!succeeded) {
      return;
    }

    _toast(
      user.isHidden
          ? '${user.displayName} を表示対象にしました'
          : '${user.displayName} を非表示対象にしました',
    );
  }

  List<UserProfile> _displayUsers() {
    if (_adminMode) {
      final allUsers = [..._users];
      allUsers.sort((a, b) {
        final aHidden = a.isHidden;
        final bHidden = b.isHidden;
        if (aHidden != bHidden) {
          return aHidden ? 1 : -1;
        }
        return a.displayName.compareTo(b.displayName);
      });
      return allUsers;
    }

    return _users.where((u) => !u.isHidden).toList();
  }

  Future<void> _createUser() async {
    if (_busy) {
      return;
    }

    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'ユーザー追加',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '表示名'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (name == null) {
      return;
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _toast('表示名を入力してください');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final created = await widget.userGateway.registerUser(trimmed);
      if (!mounted) {
        return;
      }

      setState(() {
        _users = [created, ..._users];
      });
      _toast('ユーザーを追加しました');
    } catch (e) {
      _toast('追加に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  ImageProvider? _iconProvider(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) {
      return null;
    }
    try {
      final data = Uri.parse(dataUrl).data;
      if (data == null) {
        return null;
      }
      return MemoryImage(data.contentAsBytes());
    } catch (_) {
      return null;
    }
  }

  Future<void> _editName(UserProfile user) async {
    final ctrl = TextEditingController(text: user.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'ユーザー名変更',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '表示名'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (name == null) {
      return;
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _toast('表示名は必須です');
      return;
    }

    await _updateUser(user, displayName: trimmed);
  }

  String _guessMimeTypeFromExt(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'avif':
        return 'image/avif';
      default:
        return 'image/png';
    }
  }

  String _guessMimeType(Uint8List bytes, String? ext) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'image/gif';
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'image/bmp';
    }

    return _guessMimeTypeFromExt(ext);
  }

  Future<Uint8List?> _loadPickedBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final stream = file.readStream;
    if (stream == null) {
      return null;
    }

    final buffer = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      buffer.add(chunk);
      if (buffer.length > _maxSourceIconBytes) {
        break;
      }
    }

    return buffer.takeBytes();
  }

  Future<Uint8List?> _openCropDialog(Uint8List imageBytes) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IconCropDialog(imageBytes: imageBytes),
    );
  }

  Future<void> _pickIcon(UserProfile user) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      withReadStream: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final f = result.files.first;
    final bytes = await _loadPickedBytes(f);
    if (bytes == null) {
      _toast('画像ファイルの読み込みに失敗しました');
      return;
    }

    if (bytes.length > _maxSourceIconBytes) {
      _toast('元画像が大きすぎます（最大 ${_maxSourceIconBytes ~/ 1024}KB）');
      return;
    }

    final croppedBytes = await _openCropDialog(bytes);
    if (croppedBytes == null) {
      return;
    }

    if (croppedBytes.length > _maxIconBytes) {
      _toast('切り抜き後の画像が大きすぎます（最大 ${_maxIconBytes ~/ 1024}KB）');
      return;
    }

    final mime = _guessMimeType(croppedBytes, f.extension);
    final dataUrl = 'data:$mime;base64,${base64Encode(croppedBytes)}';
    await _updateUser(user, iconDataUrl: dataUrl);
  }

  Future<void> _updateVoice(UserProfile user, int voiceId) async {
    await _updateUser(user, riichiVoiceId: voiceId);
  }

  Future<bool> _updateUser(
    UserProfile user, {
    String? displayName,
    int? riichiVoiceId,
    String? iconDataUrl,
    bool? isHidden,
  }) async {
    if (_busy) {
      return false;
    }

    setState(() {
      _busy = true;
    });

    try {
      final updated = await widget.userGateway.updateUser(
        userId: user.userId,
        displayName: displayName ?? user.displayName,
        riichiVoiceId: riichiVoiceId ?? user.riichiVoiceId,
        iconDataUrl: iconDataUrl ?? user.iconDataUrl,
        isHidden: isHidden,
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _users = _users
            .map((u) => u.userId == updated.userId ? updated : u)
            .toList();
      });
      return true;
    } catch (e) {
      _toast('更新に失敗しました: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUsers = _displayUsers();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTitleTapped,
          child: const Text('ユーザー管理'),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecordsPage(),
                ),
              );
            },
            icon: const Icon(Icons.leaderboard),
            tooltip: '戦績ページ',
          ),
          IconButton(
            onPressed: _busy ? null : _createUser,
            icon: const Icon(Icons.person_add),
            tooltip: 'ユーザー追加',
          ),
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final u in displayUsers) _userCard(u),
          if (displayUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _busy
                    ? '読み込み中...'
                    : (_adminMode ? 'ユーザーが登録されていません' : '表示中のユーザーはいません'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userCard(UserProfile u) {
    final icon = _iconProvider(u.iconDataUrl);
    final voicePreset = riichiVoicePresetById(u.riichiVoiceId);
    final isHidden = u.isHidden;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  backgroundImage: icon,
                  child:
                      icon == null ? const Icon(Icons.person, size: 20) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      if (_adminMode && isHidden)
                        Text(
                          '非表示中',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        u.userId,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => _editName(u),
                  icon: const Icon(Icons.edit),
                  tooltip: '名前変更',
                ),
                IconButton(
                  onPressed: _busy ? null : () => _pickIcon(u),
                  icon: const Icon(Icons.image),
                  tooltip: 'アイコン変更',
                ),
              ],
            ),
            if (_adminMode) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isHidden ? '戦績一覧: 非表示' : '戦績一覧: 表示',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _toggleUserHidden(u),
                    icon: Icon(
                        isHidden ? Icons.visibility : Icons.visibility_off),
                    label: Text(isHidden ? '表示化' : '非表示化'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: voicePreset.id,
                    items: riichiVoicePresets
                        .map((p) => DropdownMenuItem<int>(
                            value: p.id, child: Text(p.label)))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) async {
                            if (v == null) {
                              return;
                            }
                            await _updateVoice(u, v);
                          },
                    decoration: const InputDecoration(labelText: 'リーチボイス'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      _busy ? null : () => _voicePlayer.play(voicePreset.id),
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'プレビュー',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
