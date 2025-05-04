import 'package:flutter/material.dart';
import 'package:macrodash_models/models.dart';
import 'package:logging/logging.dart';

import 'settings.dart';
import 'sparkline.dart';
import 'api.dart';
import 'result.dart';
import 'fixed_height_grid_delegate.dart';

final _log = Logger('DashPanel');

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

  Widget _buildTickerCard() {
    assert(_customTickerResult != null, 'Custom ticker result is null');
    final change24h = _calculateChange24h(_customTickerResult!.data);
    final sparklineData = _calculateSparklineValues(_customTickerResult!.data);
    final isUp = change24h >= 0;
    final changeColor = isUp ? Colors.green : Colors.red;
    final changePrefix = isUp ? '+' : '';

    return Card(
      //margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Stock name
            TextButton(
              onPressed: widget.onTitleTap,
              child: Text(
                _customTickerResult!.description,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Stock value
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _customTickerResult!.data.last.amount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 2),
                Text(
                  _customTickerResult!.currency,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // 24h change
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '24h',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$changePrefix${change24h.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(child: SizedBox()),
            // Sparkline
            SizedBox(
              width: 100,
              height: 25,
              child: CustomPaint(
                painter: SparkPainter(
                  sparklineData.sparkline,
                  timestamps: sparklineData.sparklineTimestamps,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Remove button
                IconButton(
                  icon: const Icon(Icons.remove_circle, size: 12),
                  tooltip: 'Remove',
                  onPressed: widget.onRemove,
                  // make it smaller
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 4),
                // Config button
                IconButton(
                  icon: const Icon(Icons.settings, size: 12),
                  tooltip: 'Configure',
                  onPressed: widget.onConfig,
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
        return _buildTickerCard();
    }
  }
}

class DashPanel extends StatefulWidget {
  const DashPanel({super.key});

  @override
  State<DashPanel> createState() => _DashPanelState();
}

class _DashPanelState extends State<DashPanel> {
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

  @override
  Widget build(BuildContext context) {
    // TODO: UI to search, add, modify tickers

    final width = MediaQuery.of(context).size;
    const cardWidth = 400.0;
    final columns = (width.width / cardWidth).floor();

    return GridView.builder(
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
                      return AlertDialog(
                        title: const Text('Add Ticker'),
                        content: const Text('Add ticker options go here'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          );
        }
        return DashCard(
          ticker: _tickers.tickers[index],
          onTitleTap: () {
            _log.info('Tapped on ${_tickers.tickers[index].ticker1}');
            // TODO: open ticker details (big chart)
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
                // TODO: save the new list to settings
              }
            });
          },
          onConfig: () {
            _log.info('Configuring ${_tickers.tickers[index].ticker1}');
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Configure Ticker'),
                  content: const Text('Configuration options go here'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
