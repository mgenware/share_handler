# share_handler_ios

This is an implementation of the `share_handler_platform_interface` package for iOS.

## Usage

### With the `share_handler` plugin

This package is the endorsed implementation of the `share_handler` plugin, so it gets automatically added to your [dependencies](https://flutter.dev/platform-plugins/) by adding the `share_handler` package to your `pubspec.yaml`:

```yaml
dependencies:
  share_handler:
```

On iOS, `getInitialSharedMedia()` does not clear cached files. After it returns
`null`, your app can explicitly clear the previous cache:

```dart
final media = await ShareHandlerPlatform.instance.getInitialSharedMedia();
if (media == null) {
  await ShareHandlerIosPlatform.clearCache();
}
```

When using the `share_handler` package, call `ShareHandler.clearCache()` instead.

### Handling file URLs in a scene delegate

File URLs are not handled automatically by the plugin's scene delegate callbacks.
Call `ShareHandlerIosPlatform.handleOpenURI` from your app's `UISceneDelegate`
after calling `super`:

```swift
import share_handler_ios

override func scene(
  _ scene: UIScene,
  willConnectTo session: UISceneSession,
  options connectionOptions: UIScene.ConnectionOptions
) {
  super.scene(scene, willConnectTo: session, options: connectionOptions)
  if let context = connectionOptions.urlContexts.first {
    ShareHandlerIosPlatform.handleOpenURI(context, setInitialData: true)
  }
}

override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
  super.scene(scene, openURLContexts: URLContexts)
  if let context = URLContexts.first {
    ShareHandlerIosPlatform.handleOpenURI(context, setInitialData: false)
  }
}
```
