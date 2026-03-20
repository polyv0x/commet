library;

import 'package:tungstn/config/build_config.dart';
import 'package:tungstn/config/platform_utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppConfig {
  static Future<String> getDatabasePath() async {
    if (BuildConfig.WEB) {
      return "tungstn";
    }
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, "db");
  }

  static Future<String> getSocketPath() async {
    if (PlatformUtils.isWindows) {
      return r"\\.\pipe\chat.tungstn.app";
    }

    final dir = await getApplicationSupportDirectory();
    return join(dir.path, "socket");
  }

  static Future<String> getDriftDatabasePath() async {
    if (BuildConfig.WEB) {
      return "tungstn";
    }
    final dir = await getDatabasePath();
    return join(dir, "account", "drift");
  }
}
