import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:macrodash_models/models.dart';

import 'config.dart';
import 'settings.dart';
import 'amount_series_page.dart';
import 'market_cap_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'dash.dart';

final log = Logger('mainlogger');
SharedPreferences? _prefs;

enum AppPage {
  m2,
  debt,
  bondRates,
  indices,
  futures,
  marketCap,
  settings,
  about,
}

const _pageTitles = {
  AppPage.m2: 'M2',
  AppPage.debt: 'Debt',
  AppPage.bondRates: 'Bond Rates',
  AppPage.indices: 'Indices',
  AppPage.futures: 'Futures',
  AppPage.marketCap: 'Market Cap',
  AppPage.settings: 'Settings',
  AppPage.about: 'About',
};
String _pageTitle(AppPage page) {
  return _pageTitles[page] ?? 'Unknown';
}

void main() async {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  log.info('build GIT SHA: $gitSha');
  log.info('build date: $buildDate');

  WidgetsFlutterBinding.ensureInitialized();
  _prefs = await SharedPreferences.getInstance();
  log.info('SharedPreferences initialized');
  runApp(const MyApp());
}

String? _chartSetting(
  GoRouterState state,
  String chartName,
  String chartSetting,
) {
  final querySetting = state.uri.queryParameters[chartSetting];
  if (querySetting != null) {
    return querySetting;
  }
  // If the query parameter is not present, load the setting from shared preferences
  assert(_prefs != null, 'SharedPreferences not initialized');
  return Settings.loadChartSetting(_prefs!, chartName, chartSetting);
}

ChartLibrary _chartLibrary() {
  // Load the chart library from shared preferences
  assert(_prefs != null, 'SharedPreferences not initialized');
  return Settings.loadChartLibrary(_prefs!);
}

final _router = GoRouter(
  routes: [
    GoRoute(
      name: 'home',
      path: '/',
      builder: (context, state) => const MyHomePage(title: 'MacroDash'),
      routes: <RouteBase>[
        GoRoute(
          name: AppPage.m2.name,
          path: '/m2',
          builder:
              (context, state) => AmountSeriesPage(
                title: _pageTitle(AppPage.m2),
                chartLibrary: _chartLibrary(),
                region: _chartSetting(state, _pageTitle(AppPage.m2), 'region'),
                regions: M2Region.values,
                regionLabels: m2RegionLabels,
                zoom: _chartSetting(state, _pageTitle(AppPage.m2), 'zoom'),
              ),
        ),
        GoRoute(
          name: AppPage.debt.name,
          path: '/debt',
          builder:
              (context, state) => AmountSeriesPage(
                title: _pageTitle(AppPage.debt),
                chartLibrary: _chartLibrary(),
                region: _chartSetting(
                  state,
                  _pageTitle(AppPage.debt),
                  'region',
                ),
                regions: DebtRegion.values,
                regionLabels: debtRegionLabels,
                zoom: _chartSetting(state, _pageTitle(AppPage.debt), 'zoom'),
              ),
        ),
        GoRoute(
          name: AppPage.bondRates.name,
          path: '/bondRates',
          builder:
              (context, state) => AmountSeriesPage(
                title: _pageTitle(AppPage.bondRates),
                chartLibrary: _chartLibrary(),
                region: _chartSetting(
                  state,
                  _pageTitle(AppPage.bondRates),
                  'region',
                ),
                regions: BondRateRegion.values,
                regionLabels: bondRateRegionLabels,
                category: _chartSetting(
                  state,
                  _pageTitle(AppPage.bondRates),
                  'category',
                ),
                categories: [BondTerm.values],
                categoryLabels: [bondTermLabels],
                categoryTitles: ['Term'],
                zoom: _chartSetting(
                  state,
                  _pageTitle(AppPage.bondRates),
                  'zoom',
                ),
              ),
        ),
        GoRoute(
          name: AppPage.indices.name,
          path: '/indices',
          builder:
              (context, state) => AmountSeriesPage(
                title: _pageTitle(AppPage.indices),
                chartLibrary: _chartLibrary(),
                region: _chartSetting(
                  state,
                  _pageTitle(AppPage.indices),
                  'region',
                ),
                regions: MarketIndexRegion.values,
                regionLabels: marketIndexRegionLabels,
                category: _chartSetting(
                  state,
                  _pageTitle(AppPage.indices),
                  'category',
                ),
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
                zoom: _chartSetting(state, _pageTitle(AppPage.indices), 'zoom'),
              ),
        ),
        GoRoute(
          name: AppPage.futures.name,
          path: '/futures',
          builder:
              (context, state) => AmountSeriesPage(
                title: _pageTitle(AppPage.futures),
                chartLibrary: _chartLibrary(),
                region: _chartSetting(
                  state,
                  _pageTitle(AppPage.futures),
                  'region',
                ),
                regions: Futures.values,
                regionLabels: futuresLabels,
                zoom: _chartSetting(state, _pageTitle(AppPage.futures), 'zoom'),
              ),
        ),
        GoRoute(
          name: AppPage.marketCap.name,
          path: '/marketCap',
          builder:
              (context, state) => MarketCapPage(
                title: _pageTitle(AppPage.marketCap),
                market: _chartSetting(
                  state,
                  _pageTitle(AppPage.marketCap),
                  'market',
                ),
              ),
        ),
        GoRoute(
          name: AppPage.settings.name,
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          name: AppPage.about.name,
          path: '/about',
          builder: (context, state) => const AboutPage(),
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MacroDash',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: _router,
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
    // close the drawer
    Navigator.pop(context);
    // load the shared preferences
    _prefs = await SharedPreferences.getInstance();
    // navigate to the selected page
    if (mounted) {
      switch (page) {
        case AppPage.m2:
          log.info('Navigating to M2');
          context.goNamed(AppPage.m2.name);
        case AppPage.debt:
          log.info('Navigating to Debt');
          context.goNamed(AppPage.debt.name);
        case AppPage.bondRates:
          log.info('Navigating to Bond Rates');
          context.goNamed(AppPage.bondRates.name);
        case AppPage.indices:
          log.info('Navigating to Indices');
          context.goNamed(AppPage.indices.name);
        case AppPage.futures:
          log.info('Navigating to Futures');
          context.goNamed(AppPage.futures.name);
          break;
        case AppPage.marketCap:
          log.info('Navigating to Market Cap');
          context.goNamed(AppPage.marketCap.name);
        case AppPage.settings:
          log.info('Navigating to Settings');
          context.goNamed(AppPage.settings.name);
        case AppPage.about:
          log.info('Navigating to About');
          context.goNamed(AppPage.about.name);
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
              onTap: () => _navigateToPage(AppPage.m2),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Debt'),
              onTap: () => _navigateToPage(AppPage.debt),
            ),
            ListTile(
              leading: const Icon(Icons.percent),
              title: const Text('Bond Rates'),
              onTap: () => _navigateToPage(AppPage.bondRates),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Indices'),
              onTap: () => _navigateToPage(AppPage.indices),
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Futures'),
              onTap: () => _navigateToPage(AppPage.futures),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart),
              title: const Text('Market Cap'),
              onTap: () => _navigateToPage(AppPage.marketCap),
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
              onTap: () => _navigateToPage(AppPage.settings),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () => _navigateToPage(AppPage.about),
            ),
          ],
        ),
      ),
      body: DashPanel(),
    );
  }
}
