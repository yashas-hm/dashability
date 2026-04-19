import 'package:appium_driver/async_io.dart';

/// Controls a running app via Appium for autonomous interaction.
///
/// Provides tap, scroll, type, and app lifecycle actions.
/// Gracefully optional — if Appium is not available, dashability
/// runs in observation-only mode.
class AppiumActor {
  final Uri _appiumUrl;
  AppiumWebDriver? _driver;

  AppiumActor({Uri? appiumUrl})
    : _appiumUrl = appiumUrl ?? Uri.parse('http://localhost:4723');

  /// Whether a driver session is active.
  bool get isConnected => _driver != null;

  /// Connect to the Appium server and create a session.
  Future<void> connect({required Map<String, dynamic> capabilities}) async {
    _driver = await createDriver(uri: _appiumUrl, desired: capabilities);
  }

  /// Disconnect and end the Appium session.
  Future<void> disconnect() async {
    await _driver?.quit();
    _driver = null;
  }

  /// Tap an element found by text content.
  Future<void> tapByText(String text) async {
    _ensureConnected();
    final element = await _driver!.findElement(AppiumBy.accessibilityId(text));
    await element.click();
  }

  /// Tap an element found by accessibility ID.
  Future<void> tapById(String id) async {
    _ensureConnected();
    final element = await _driver!.findElement(AppiumBy.accessibilityId(id));
    await element.click();
  }

  /// Scroll in a direction on the screen.
  Future<void> scroll({
    required String direction,
    double distance = 500,
  }) async {
    _ensureConnected();
    final window = await _driver!.window;
    final size = await window.size;
    final centerX = size.width ~/ 2;
    final centerY = size.height ~/ 2;

    int endX = centerX;
    int endY = centerY;

    switch (direction) {
      case 'up':
        endY = centerY - distance.toInt();
      case 'down':
        endY = centerY + distance.toInt();
      case 'left':
        endX = centerX - distance.toInt();
      case 'right':
        endX = centerX + distance.toInt();
    }

    await _driver!.execute('mobile: swipe', [
      {
        'startX': centerX,
        'startY': centerY,
        'endX': endX,
        'endY': endY,
        'duration': 300,
      },
    ]);
  }

  /// Type text into an element found by accessibility ID.
  Future<void> type({required String field, required String value}) async {
    _ensureConnected();
    final element = await _driver!.findElement(AppiumBy.accessibilityId(field));
    await element.clear();
    await element.sendKeys(value);
  }

  /// Check if an element with the given text is visible.
  Future<bool> isVisible(String text) async {
    _ensureConnected();
    try {
      final element = await _driver!.findElement(
        AppiumBy.accessibilityId(text),
      );
      return await element.displayed;
    } catch (_) {
      return false;
    }
  }

  void _ensureConnected() {
    if (_driver == null) {
      throw StateError('Not connected to Appium. Call connect() first.');
    }
  }
}
