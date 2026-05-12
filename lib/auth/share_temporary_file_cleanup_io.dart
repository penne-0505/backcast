import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ShareTemporaryFileCleanup {
  const ShareTemporaryFileCleanup();

  Future<void> deleteShareTemporaryFiles() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/medo_share.png');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
