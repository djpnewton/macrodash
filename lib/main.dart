import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'config.dart';
import 'amount_series_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'package:macrodash_models/models.dart';

final log = Logger('mainlogger');

enum AppPage { m2, debt, bondRates, settings, about }

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
  void _navigateToPage(AppPage page) {
    switch (page) {
      case AppPage.m2:
        log.info('Navigating to M2');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => AmountSeriesPage(
                  title: 'M2',
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
                  defaultRegion: BondRateRegion.usa,
                  regions: BondRateRegion.values,
                  regionLabels: bondRateRegionLabels,
                  categories: BondTerm.values,
                  categoryLabels: bondTermLabels,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
