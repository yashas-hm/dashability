import 'dart:math';

import 'package:dashability_extensions/dashability_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const DashabilityExampleApp());
}

class DashabilityExampleApp extends StatelessWidget {
  const DashabilityExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashability Example',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashability Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoCard(
            title: 'Janky Counter',
            subtitle: 'Triggers heavy rebuilds on every frame',
            onTap: () {
              DashabilityReporter.interaction('navigate_janky_counter');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JankyCounterPage()),
              );
            },
          ),
          _DemoCard(
            title: 'Heavy List',
            subtitle: 'Unoptimized scroll list with expensive items',
            onTap: () {
              DashabilityReporter.interaction('navigate_heavy_list');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HeavyListPage()),
              );
            },
          ),
          _DemoCard(
            title: 'Error Thrower',
            subtitle: 'Triggers an unhandled exception',
            onTap: () {
              DashabilityReporter.interaction('trigger_error');
              throw Exception('Deliberate test error from Dashability example');
            },
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// A deliberately janky page that rebuilds on every frame.
class JankyCounterPage extends StatefulWidget {
  const JankyCounterPage({super.key});

  @override
  State<JankyCounterPage> createState() => _JankyCounterPageState();
}

class _JankyCounterPageState extends State<JankyCounterPage>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    DashabilityReporter.screen('JankyCounter');
    // Rebuild on every frame — deliberately wasteful.
    _ticker = createTicker((_) {
      setState(() {
        _frameCount++;
        // Simulate expensive computation.
        _expensiveWork();
      });
    });
    _ticker.start();
  }

  void _expensiveWork() {
    // Deliberately burn CPU to cause jank.
    var sum = 0.0;
    for (var i = 0; i < 50000; i++) {
      sum += sin(i.toDouble()) * cos(i.toDouble());
    }
    DashabilityReporter.metric('computation_result', sum);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Janky Counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Frame: $_frameCount', style: Theme
                .of(context)
                .textTheme
                .displayMedium),
            const SizedBox(height: 16),
            const Text(
                'This page rebuilds every frame with expensive computation.'),
          ],
        ),
      ),
    );
  }
}

/// A deliberately heavy scroll list with unoptimized items.
class HeavyListPage extends StatelessWidget {
  const HeavyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    DashabilityReporter.screen('HeavyList');
    return Scaffold(
      appBar: AppBar(title: const Text('Heavy List')),
      body: ListView.builder(
        itemCount: 10000,
        // No itemExtent, no const widgets, rebuilds everything.
        itemBuilder: (context, index) {
          // Simulate expensive item build.
          final colors = List.generate(
            20,
                (i) =>
                Color.fromARGB(255, (index * 7 + i * 13) % 256,
                    (index * 11 + i * 17) % 256, (index * 3 + i * 23) % 256),
          );
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors.take(3).toList()),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: Text('Item #$index'),
            subtitle: Text('Colors: ${colors.length} generated'),
          );
        },
      ),
    );
  }
}
