import 'package:flutter/material.dart';

import 'config.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to the About Page!',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Text(
              'Build SHA: $gitSha', // Access gitSha from config.dart
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Build Date: $buildDate', // Access buildDate from config.dart
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
