import 'package:dashability_extensions/dashability_extensions.dart';

void main() {
  // Report a user interaction.
  DashabilityReporter.interaction('button_pressed');

  // Report a custom metric.
  DashabilityReporter.metric('items_loaded', 42);

  // Report a screen/route change.
  DashabilityReporter.screen('HomeScreen');

  // Report a custom event with arbitrary data.
  DashabilityReporter.event('purchase', {
    'item': 'widget_pack',
    'price': 9.99,
  });
}
