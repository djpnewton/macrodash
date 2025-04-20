import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'settings.dart';
import 'amount_series_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'package:macrodash_models/models.dart';

final log = Logger('mainlogger');

enum AppPage { m2, debt, bondRates, indexes, settings, about }

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  log.info('build GIT SHA: $gitSha');
  log.info('build date: $buildDate');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacroDash',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'MacroDash'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _navigateToPage(AppPage page) async {
    final chartLibrary = await Settings.loadChartLibrary();
    if (mounted) {
      switch (page) {
        case AppPage.m2:
          log.info('Navigating to M2');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AmountSeriesPage(
                    title: 'M2',
                    chartLibrary: chartLibrary,
                    defaultRegion: M2Region.usa,
                    regions: M2Region.values,
                    regionLabels: m2RegionLabels,
                  ),
            ),
          );
          break;
        case AppPage.debt:
          log.info('Navigating to Debt');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AmountSeriesPage(
                    title: 'Debt',
                    chartLibrary: chartLibrary,
                    defaultRegion: DebtRegion.usa,
                    regions: DebtRegion.values,
                    regionLabels: debtRegionLabels,
                  ),
            ),
          );
          break;
        case AppPage.bondRates:
          log.info('Navigating to Bond Rates');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AmountSeriesPage(
                    title: 'Bond Rates',
                    chartLibrary: chartLibrary,
                    defaultRegion: BondRateRegion.usa,
                    regions: BondRateRegion.values,
                    regionLabels: bondRateRegionLabels,
                    categories: [BondTerm.values],
                    categoryLabels: [bondTermLabels],
                    categoryTitles: ['Term'],
                  ),
            ),
          );
          break;
        case AppPage.indexes:
          log.info('Navigating to Indexes');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AmountSeriesPage(
                    title: 'Indexes',
                    chartLibrary: chartLibrary,
                    defaultRegion: MarketIndexRegion.usa,
                    regions: MarketIndexRegion.values,
                    regionLabels: marketIndexRegionLabels,
                    categories: [
                      MarketIndexUsa.values,
                      MarketIndexEurope.values,
                      MarketIndexAsia.values,
                    ],
                    categoryLabels: [
                      marketIndexUsaLabels,
                      marketIndexEuropeLabels,
                      marketIndexAsiaLabels,
                    ],
                    categoryTitles: ['Index', 'Index', 'Index'],
                  ),
            ),
          );
          break;
        case AppPage.settings:
          log.info('Navigating to Settings');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
          break;
        case AppPage.about:
          log.info('Navigating to About');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AboutPage()),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 520;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions:
            isNarrow
                ? null
                : [
                  TextButton.icon(
                    onPressed: () {
                      const url = 'https://github.com/djpnewton/macrodash';
                      launchUrl(Uri.parse(url));
                    },
                    icon: const Icon(Icons.code, size: 12),
                    label: const Text(
                      'Contribute on GitHub',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      const url = 'https://taxmap.me';
                      launchUrl(Uri.parse(url));
                    },
                    icon: const Icon(Icons.public, size: 12),
                    label: const Text(
                      'Visit taxmap.me',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                'Navigation',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text('M2'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _navigateToPage(AppPage.m2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Debt'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _navigateToPage(AppPage.debt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.percent),
              title: const Text('Bond Rates'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _navigateToPage(AppPage.bondRates);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Indexes'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _navigateToPage(AppPage.indexes);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Contribute on GitHub'),
              onTap: () {
                const url = 'https://github.com/djpnewton/macrodash';
                launchUrl(Uri.parse(url));
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Visit taxmap.me'),
              onTap: () {
                const url = 'https://taxmap.me';
                launchUrl(Uri.parse(url));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _navigateToPage(AppPage.settings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _navigateToPage(AppPage.about);
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Welcome to MacroDash!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Hoping to create a macro dashboard to simplify your workflow!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
