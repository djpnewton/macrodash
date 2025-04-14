import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macrodash_models/models.dart';

import 'helper.dart' as helper;
import 'config.dart';
import 'api.dart';
import 'result.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final ServerApi _api = ServerApi();
  VersionInfo? _versionInfo;
  bool _isLoading = true;

  void _updateWeb() {
    helper.reloadPage();
  }

  @override
  void initState() {
    super.initState();
    _fetchVersionInfo();
  }

  Future<void> _fetchVersionInfo() async {
    final result = await _api.serverVersion();
    switch (result) {
      case Ok():
        _versionInfo = result.value;
      case Error():
        // show snackbar
        if (mounted) {
          var snackBar = SnackBar(
            content: Text('Unable to get version! - ${result.error}'),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
    }
    setState(() {
      _versionInfo = _versionInfo;
      _isLoading = false;
    });
  }

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
            Text('Build SHA: $gitSha', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text(
              'Build Date: $buildDate',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Server URL: $macrodashServerUrl',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Client Version: $clientVersion',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (_isLoading) ...[
              const CircularProgressIndicator(),
            ] else if (_versionInfo == null) ...[
              const Text(
                'Failed to load server version information.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ] else ...[
              Text(
                'Server Version: ${_versionInfo!.version} (Minimum Client Version: ${_versionInfo!.minClientVersion})',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            if (_versionInfo != null &&
                _versionInfo!.minClientVersion > clientVersion) ...[
              const SizedBox(height: 20),
              if (kIsWeb) ...[
                ElevatedButton(
                  onPressed: _updateWeb,
                  child: const Text('Update'),
                ),
              ] else ...[
                const Text(
                  'A new version is available. Please update your client.',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
