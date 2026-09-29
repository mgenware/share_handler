import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:share_handler/share_handler.dart';

class MockShareHandlerPlatform extends Mock implements ShareHandlerPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareHandler', () {
    test('can be instantiated', () {
      expect(
        ShareHandler.instance,
        isNotNull,
      );
    });

    test('clearCache invokes the iOS cache cleanup channel', () async {
      const channel =
          MethodChannel('com.shoutsocial.share_handler/sharedFiles');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'clearCache');
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await ShareHandler.clearCache();
    });
  });
}
