import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ImageExportDelivery {
  const ImageExportDelivery();

  Future<Uint8List> capturePng(GlobalKey key, {double pixelRatio = 3.0}) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError(
        'RenderRepaintBoundary not found. Ensure the widget is built '
        'and wrapped in RepaintBoundary.',
      );
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> sharePng(
    Uint8List bytes, {
    required BuildContext context,
    String fileName = 'medo_share.png',
  }) {
    throw UnsupportedError(
      'Image sharing is not supported on Flutter Web yet.',
    );
  }
}
