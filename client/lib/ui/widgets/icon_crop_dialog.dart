import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class IconCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const IconCropDialog({
    super.key,
    required this.imageBytes,
  });

  @override
  State<IconCropDialog> createState() => _IconCropDialogState();
}

class _IconCropDialogState extends State<IconCropDialog> {
  final _cropController = CropController();

  CropStatus _cropStatus = CropStatus.nothing;
  bool _cropping = false;
  String? _error;

  bool get _canCrop => _cropStatus == CropStatus.ready && !_cropping;

  void _requestCrop() {
    if (!_canCrop) {
      return;
    }
    setState(() {
      _cropping = true;
      _error = null;
    });
    _cropController.crop();
  }

  void _handleCropped(CropResult result) {
    if (!mounted) {
      return;
    }

    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() {
          _cropping = false;
          _error = '切り抜きに失敗しました。別の画像でお試しください。';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          maxHeight: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'アイコン画像の調整',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _cropping ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Crop(
                    image: widget.imageBytes,
                    controller: _cropController,
                    onCropped: _handleCropped,
                    onStatusChanged: (status) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _cropStatus = status;
                      });
                    },
                    aspectRatio: 1,
                    withCircleUi: true,
                    interactive: true,
                    initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                      size: 0.8,
                      aspectRatio: 1,
                    ),
                    maskColor: Colors.black.withValues(alpha: 0.55),
                    baseColor: Theme.of(context).colorScheme.surface,
                    progressIndicator:
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '画像をドラッグして位置を調整。ピンチまたはホイールで拡大・縮小できます。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _cropping ? null : () => Navigator.of(context).pop(),
                      child: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _canCrop ? _requestCrop : null,
                      icon: Icon(_cropping ? Icons.hourglass_top : Icons.crop),
                      label: Text(_cropping ? '切り抜き中…' : 'この範囲で保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
