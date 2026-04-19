/// A Flutter device discovered via `flutter devices --machine`.
class FlutterDevice {
  /// Device identifier (e.g. `emulator-5554`, `00008030-001A1C2E3A90002E`).
  final String id;

  /// Human-readable device name (e.g. `Pixel 7`, `iPhone 15 Pro`).
  final String name;

  /// Target platform (e.g. `android-arm64`, `ios`).
  final String platform;

  /// Whether this is an emulator/simulator rather than a physical device.
  final bool isEmulator;

  const FlutterDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.isEmulator,
  });

  /// Creates a [FlutterDevice] from `flutter devices --machine` JSON output.
  factory FlutterDevice.fromJson(Map<String, dynamic> json) {
    return FlutterDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      platform: json['targetPlatform'] as String? ??
          json['platform'] as String? ?? 'unknown',
      isEmulator: json['emulator'] as bool? ?? false,
    );
  }

  /// Serializes this device to a JSON-compatible map.
  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'name': name,
        'platform': platform,
        'is_emulator': isEmulator,
      };

  @override
  String toString() => '$name ($id) [$platform]';
}
