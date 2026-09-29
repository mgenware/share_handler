import 'package:share_handler_ios/share_handler_ios.dart';
import 'package:share_handler_platform_interface/share_handler_platform_interface.dart';

class ShareHandler {
  /// Gets ShareHandlerPlatform instance to use.
  static ShareHandlerPlatform get instance => ShareHandlerPlatform.instance;

  /// iOS only: removes plugin-owned shared files after they have been processed.
  static Future<void> clearCache() => ShareHandlerIosPlatform.clearCache();
}
