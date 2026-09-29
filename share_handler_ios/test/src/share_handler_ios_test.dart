import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_handler_ios/share_handler_ios.dart';
import 'package:share_handler_platform_interface/share_handler_platform_interface.dart';

void main() {
  const initialChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.ShareHandlerApi.getInitialSharedMedia',
    ShareHandlerApi.codec,
  );
  const filesChannel = MethodChannel(
    'com.shoutsocial.share_handler/sharedFiles',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  SharedMedia? initialMedia;
  var clearCacheCalls = 0;

  setUp(() {
    initialMedia = null;
    clearCacheCalls = 0;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler(initialChannel, (message) async {
      return <Object?, Object?>{'result': initialMedia};
    });
    messenger.setMockMethodCallHandler(filesChannel, (call) async {
      expect(call.method, 'clearCache');
      clearCacheCalls++;
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler(initialChannel, null);
    messenger.setMockMethodCallHandler(filesChannel, null);
  });

  test('null initial media leaves cache clearing to the app', () async {
    final handler = ShareHandlerIosPlatform();

    expect(await handler.getInitialSharedMedia(), isNull);
    expect(clearCacheCalls, 0);

    expect(await handler.getInitialSharedMedia(), isNull);
    expect(clearCacheCalls, 0);

    await ShareHandlerIosPlatform.clearCache();
    expect(clearCacheCalls, 1);
  });

  test('share launch preserves the cache until explicitly cleared', () async {
    initialMedia = SharedMedia(content: 'shared');
    final handler = ShareHandlerIosPlatform();

    expect((await handler.getInitialSharedMedia())?.content, 'shared');
    initialMedia = null;
    expect(await handler.getInitialSharedMedia(), isNull);
    expect(clearCacheCalls, 0);

    await ShareHandlerIosPlatform.clearCache();
    expect(clearCacheCalls, 1);
  });
}
