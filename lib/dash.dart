import 'package:flutter/material.dart';
import 'package:macrodash_models/models.dart';
import 'package:logging/logging.dart';
import 'package:go_router/go_router.dart';

import 'settings.dart';
import 'sparkline.dart';
import 'fixed_height_grid_delegate.dart';
import 'ticker_search.dart';
import 'api.dart';
import 'result.dart';
import 'helper.dart';
import 'amount_series_page.dart';
import 'config.dart';

final _log = Logger('DashPanel');

class TickerSelection {
  final String label;
  final String value;
  const TickerSelection({required this.label, required this.value});
}

class TickerConfig extends StatefulWidget {
  final DashTicker ticker;
  final ValueSetter<DashTicker>? onSave;
  final bool add;

  const TickerConfig({
    super.key,
    required this.ticker,
    this.onSave,
    this.add = false,
  });

  @override
  State<TickerConfig> createState() => _TickerConfigState();
}

class _TickerConfigState extends State<TickerConfig> {
  late DashTicker _ticker;

  final controller1 = TextEditingController();
  final controller2 = TextEditingController();
  final SearchController searchController1 = SearchController();
  final SearchController searchController2 = SearchController();

  @override
  void initState() {
    super.initState();
    _ticker = widget.ticker;
    controller1.text = _ticker.ticker1;
    controller2.text = _ticker.ticker2 ?? '';
    searchController1.text = _ticker.ticker1;
    searchController2.text = _ticker.ticker2 ?? '';
    controller1.addListener(_updateTicker);
    controller2.addListener(_updateTicker);
    searchController1.addListener(_updateTicker);
    searchController2.addListener(_updateTicker);
  }

  @override
  void dispose() {
    controller1.dispose();
    controller2.dispose();
    searchController1.dispose();
    searchController2.dispose();
    super.dispose();
  }

  void _updateTicker() {
    controller1.text = searchController1.text;
    controller2.text = searchController2.text;
    setState(() {
      _ticker = DashTicker(
        ticker1: controller1.text,
        ticker2: controller2.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.add ? 'Add Ticker' : 'Configure Ticker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: controller1,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Ticker 1',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AsyncSearchAnchor(controller: searchController1),
                  IconButton(
                    onPressed: () => searchController1.clear(),
                    icon: Icon(Icons.clear),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller2,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Ticker 2 (Optional comparison ticker)',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AsyncSearchAnchor(controller: searchController2),
                  IconButton(
                    onPressed: () => searchController2.clear(),
                    icon: Icon(Icons.clear),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (controller1.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a ticker')),
              );
              return;
            }
            Navigator.of(context).pop();
            if (widget.onSave != null) {
              widget.onSave!(_ticker);
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}

enum DashState { loading, error, loaded }

class DashCard extends StatefulWidget {
  final DashTicker ticker;
  final VoidCallback? onConfig;
  final VoidCallback? onRemove;
  final VoidCallback? onTitleTap;

  const DashCard({
    super.key,
    required this.ticker,
    this.onConfig,
    this.onRemove,
    this.onTitleTap,
  });

  @override
  State<DashCard> createState() => _DashCardState();
}

class _DashCardState extends State<DashCard> {
  DashState _state = DashState.loading;
  CustomTickerResult? _customTickerResult;

  @override
  void initState() {
    super.initState();
    _loadTickerData();
  }

  Future<void> _loadTickerData() async {
    final api = ServerApi();
    final result = await api.fetchCustomTicker(
      widget.ticker,
      DataRange.fiveDays,
    );
    switch (result) {
      case Ok():
        setState(() {
          _state = DashState.loaded;
          _customTickerResult = result.value;
        });
      case Error():
        setState(() {
          _state = DashState.error;
        });
    }
  }

  double _calculateChange24h(List<AmountEntry> data) {
    if (data.isEmpty) return 0.0;
    // only use the dates that are in the last 24h from the last entry
    final lastDate = data.last.date;
    final last24h = data.where(
      (entry) =>
          entry.date.isAfter(lastDate.subtract(const Duration(hours: 24))),
    );
    if (last24h.isEmpty) return 0.0;
    // calculate the change from the first to the last entry
    final firstValue = last24h.first.amount;
    final lastValue = last24h.last.amount;
    if (firstValue == 0) return 0.0; // avoid division by zero
    // calculate the percentage change
    return ((lastValue - firstValue) / firstValue) * 100;
  }

  YahooSparklineData _calculateSparklineValues(List<AmountEntry> data) {
    // only use the last 7 days of data from the last entry
    final lastDate = data.last.date;
    final last7Days = data.where(
      (entry) => entry.date.isAfter(lastDate.subtract(const Duration(days: 7))),
    );
    if (last7Days.isEmpty) {
      return YahooSparklineData(sparkline: [], sparklineTimestamps: []);
    }
    return YahooSparklineData(
      sparkline: last7Days.map((entry) => entry.amount).toList(),
      sparklineTimestamps:
          last7Days.map((entry) => entry.date.millisecondsSinceEpoch).toList(),
    );
  }

  Widget _rowText(
    String top,
    double fontSizeTop,
    String bottom,
    double fontSizeBottom, {
    Color? topColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          top,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: fontSizeTop,
            color: topColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 2),
        Text(
          bottom,
          style: TextStyle(fontSize: fontSizeBottom, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _stackText(
    String top,
    double fontSizeTop,
    String bottom,
    double fontSizeBottom, {
    Color? topColor,
    Widget? topWidget,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child:
                topWidget ??
                Text(
                  top,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSizeTop,
                    color: topColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              bottom,
              style: TextStyle(fontSize: fontSizeBottom, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPriceWidgets(bool useColumn) {
    final change24h = _calculateChange24h(_customTickerResult!.data);
    final isUp = change24h >= 0;
    final changeColor = isUp ? Colors.green : Colors.red;
    final changePrefix = isUp ? '+' : '';
    final boxWidth = useColumn ? 80.0 : 65.0;
    final boxHeight = useColumn ? 25.0 : 35.0;
    final fontSize = useColumn ? 14.0 : 16.0;

    final price = SizedBox(
      width: boxWidth,
      height: boxHeight,
      child:
          useColumn
              ? _rowText(
                formatPrice(
                  _customTickerResult!.data.last.amount,
                  currencyChar: '',
                  space: '',
                ),
                fontSize,
                _customTickerResult!.currency,
                8,
              )
              : _stackText(
                formatPrice(
                  _customTickerResult!.data.last.amount,
                  currencyChar: '',
                  space: '',
                ),
                fontSize,
                _customTickerResult!.currency,
                8,
              ),
    );
    final change = SizedBox(
      width: boxWidth,
      height: boxHeight,
      child:
          useColumn
              ? _rowText(
                '$changePrefix${change24h.toStringAsFixed(2)}%',
                fontSize,
                '24h',
                8,
                topColor: changeColor,
              )
              : _stackText(
                '$changePrefix${change24h.toStringAsFixed(2)}%',
                fontSize,
                '24h',
                8,
                topColor: changeColor,
              ),
    );
    if (useColumn) {
      return [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stock value
            price,
            // 24h change
            change,
          ],
        ),
      ];
    } else {
      return [
        // Stock value
        price,
        const SizedBox(width: 4),
        // 24h change
        change,
      ];
    }
  }

  Widget _buildTickerCard(BuildContext context) {
    assert(_customTickerResult != null, 'Custom ticker result is null');
    final sparklineData = _calculateSparklineValues(_customTickerResult!.data);
    final useColumn = MediaQuery.of(context).size.width < 400;

    return Card(
      //margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Stock name
            SizedBox(
              width: 100,
              height: 35,
              child: _stackText(
                _customTickerResult!.shortName,
                16,
                _customTickerResult!.longName,
                8,
                topWidget: TextButton(
                  onPressed: widget.onTitleTap,
                  child: Text(
                    _customTickerResult!.shortName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // stock value and 24h change
            ..._buildPriceWidgets(useColumn),
            const SizedBox(width: 4),
            Expanded(child: SizedBox()),
            // Sparkline
            SizedBox(
              width: 110,
              height: 25,
              child: CustomPaint(
                painter: SparkPainter(
                  sparklineData.sparkline,
                  timestamps: sparklineData.sparklineTimestamps,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Config button
                IconButton(
                  icon: const Icon(Icons.settings, size: 12),
                  tooltip: 'Configure',
                  onPressed: widget.onConfig,
                  // make it smaller
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 4),
                // Remove button
                IconButton(
                  icon: const Icon(Icons.remove_circle, size: 12),
                  tooltip: 'Remove',
                  onPressed: widget.onRemove,
                  // make it smaller
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case DashState.loading:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Card(
            //margin: const EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      case DashState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Card(
            //margin: const EdgeInsets.all(8),
            child: Text('Error loading ticker data'),
          ),
        );
      case DashState.loaded:
        return _buildTickerCard(context);
    }
  }
}

class DashPanel extends StatefulWidget {
  const DashPanel({super.key, required this.refreshKey});

  final GlobalKey<RefreshIndicatorState> refreshKey;

  @override
  State<DashPanel> createState() => _DashPanelState();
}

class _DashPanelState extends State<DashPanel> {
  Key _refreshKey = UniqueKey();
  DashTickers _tickers = DashTickers(tickers: []);

  @override
  void initState() {
    super.initState();
    _loadTickers();
  }

  Future<void> _loadTickers() async {
    final dashTickers = Settings.loadDashTickers(await Settings.getPrefs());
    setState(() {
      _tickers = dashTickers;
    });
  }

  Future<void> _refreshTickers() async {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size;
    const cardWidth = 400.0;
    final columns = (width.width / cardWidth).floor();

    return RefreshIndicator(
      key: widget.refreshKey,
      onRefresh: _refreshTickers,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _tickers.tickers.length + 1,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
          crossAxisCount: columns > 0 ? columns : 1,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          height: 75.0,
        ),
        itemBuilder: (context, index) {
          if (index == _tickers.tickers.length) {
            return SizedBox(
              height: 75,
              child: Center(
                child: TextButton(
                  child: Text('Add Ticker'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return TickerConfig(
                          ticker: DashTicker(ticker1: '', ticker2: ''),
                          onSave: (ticker) {
                            setState(() {
                              _tickers = DashTickers(
                                tickers: _tickers.tickers + [ticker],
                              );
                            });
                            // save the new ticker to settings
                            Settings.saveDashTickers(_tickers);
                          },
                          add: true,
                        );
                      },
                    );
                  },
                ),
              ),
            );
          }
          return DashCard(
            key: ValueKey<(DashTicker, Key)>((
              _tickers.tickers[index],
              _refreshKey,
            )),
            ticker: _tickers.tickers[index],
            onTitleTap: () async {
              final ticker = _tickers.tickers[index];
              _log.info('Tapped on ${ticker.ticker1}');
              log.info('Navigating to Ticker');
              context.goNamed(
                AppPage.ticker.name,
                queryParameters: {
                  'ticker1': ticker.ticker1,
                  'ticker2': ticker.ticker2 ?? '',
                },
              );
            },
            onRemove: () {
              // are you sure?
              showDialog<bool?>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Remove Ticker'),
                    content: const Text(
                      'Are you sure you want to remove this ticker?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  );
                },
              ).then((result) {
                if (result == true) {
                  _log.info('Removing ${_tickers.tickers[index].ticker1}');
                  setState(() {
                    _tickers = DashTickers(
                      tickers:
                          _tickers.tickers
                              .where(
                                (ticker) => ticker != _tickers.tickers[index],
                              )
                              .toList(),
                    );
                  });
                  // save the new list to settings
                  Settings.saveDashTickers(_tickers);
                }
              });
            },
            onConfig: () {
              _log.info('Configuring ${_tickers.tickers[index].ticker1}');
              showDialog(
                context: context,
                builder: (context) {
                  return TickerConfig(
                    ticker: _tickers.tickers[index],
                    onSave: (ticker) {
                      setState(() {
                        _tickers = DashTickers(
                          tickers:
                              _tickers.tickers
                                  .map(
                                    (t) =>
                                        t == _tickers.tickers[index]
                                            ? ticker
                                            : t,
                                  )
                                  .toList(),
                        );
                      });
                      // save the new ticker to settings
                      Settings.saveDashTickers(_tickers);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
