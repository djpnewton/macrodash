import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macrodash_models/models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'helper.dart' as helper;
import 'config.dart';
import 'api.dart';
import 'result.dart';

const _dataSources = [
  ('Yahoo Finance', 'https://finance.yahoo.com/'),
  ('FRED', 'https://fred.stlouisfed.org/'),
  ('ECB', 'https://www.ecb.europa.eu/'),
  ('US Treasury', 'https://fiscaldata.treasury.gov/'),
  ('CoinGecko', 'https://www.coingecko.com/'),
];

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'MacroDash',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'A markets and macro dashboard: your ticker watchlist '
                  'alongside M2, debt, bond rates, indices, futures and market '
                  'caps. Your watchlist is stored on this device only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final (label, url) in _dataSources)
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(url)),
                      child: Text(label),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Data may be delayed or incomplete and is not financial '
                  'advice.',
                  textAlign: TextAlign.center,
                ),
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
                Text(
                  'Failed to load server version information.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
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
                  Text(
                    'A new version is available. Please update your client.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
