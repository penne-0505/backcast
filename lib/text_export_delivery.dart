import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// テキスト共有の delivery 層。
///
/// [share] は OS の共有シートを開き、[copyToClipboard] はクリップボードへコピーする。
/// iPad / 大画面 iOS では [context] から [sharePositionOrigin] を自動取得する。
class TextExportDelivery {
  const TextExportDelivery();

  /// テキストを OS の共有シートで共有する。
  Future<void> share(
    String text, {
    required BuildContext context,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    await Share.share(
      text,
      sharePositionOrigin: origin,
    );
  }

  /// テキストをクリップボードにコピーする。
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
