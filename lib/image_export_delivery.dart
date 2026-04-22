import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 画像共有の delivery 層。
///
/// [capturePng] は [RepaintBoundary] に紐づいた [GlobalKey] から PNG bytes を生成し、
/// [sharePng] は一時ファイルに書き出して OS の共有シートを開く。
/// iPad / 大画面 iOS では [context] から [sharePositionOrigin] を自動取得する。
class ImageExportDelivery {
  const ImageExportDelivery();

  /// [key] に紐づいた [RenderRepaintBoundary] を画像化し、PNG bytes を返す。
  ///
  /// [pixelRatio] は解像度倍率。未指定時は 3.0 を使用し、高 DPI 端末での
  /// ぼやけを抑制する。
  Future<Uint8List> capturePng(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    final boundary = key.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
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

  /// PNG bytes を一時ファイルに保存し、OS 共有シートで開く。
  Future<void> sharePng(
    Uint8List bytes, {
    required BuildContext context,
    String fileName = 'ato_share.png',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    if (!context.mounted) return;

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      sharePositionOrigin: origin,
    );
  }
}
