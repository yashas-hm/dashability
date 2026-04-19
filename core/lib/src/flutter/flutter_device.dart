/// A Flutter device discovered via `flutter devices --machine`.
class FlutterDevice {
  final String id;
  final String name;
  final String platform;
  final bool isEmulator;

  const FlutterDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.isEmulator,
  });

  factory FlutterDevice.fromJson(Map<String, dynamic> json) {
    return FlutterDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      platform: json['targetPlatform'] as String? ?? json['platform'] as String? ?? 'unknown',
      isEmulator: json['emulator'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'is_emulator': isEmulator,
      };

  @override
  String toString() => '$name ($id) [$platform]';
}
