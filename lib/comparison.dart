import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import 'api.dart';
import 'freshness.dart';
import 'helper.dart';
import 'option_buttons.dart';
import 'result.dart';

final _log = Logger('Comparison');

final comparisonColors = comparisonColorValues.map(Color.new).toList();

List<String> comparisonTickers(DashTicker ticker) => [
  ticker.ticker1,
  if (ticker.ticker2 != null && ticker.ticker2!.isNotEmpty) ticker.ticker2!,
];

enum ComparisonRange {
  oneDay('24h', DataRange.sevenDays),
  sevenDays('7D', DataRange.sevenDays),
  oneMonth('1M', DataRange.oneMonth),
  oneYear('1Y', DataRange.oneYear),
  yearToDate('YTD', DataRange.oneYear);

  const ComparisonRange(this.label, this.apiRange);
  final String label;
  final DataRange apiRange;
}

GoRoute comparisonRoute() => GoRoute(
  path: '/compare',
  builder: (context, state) {
    final link = ComparisonLink.parse(state.uri.queryParameters);
    if (link == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relative performance')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Invalid comparison link.'),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Go to dashboard'),
              ),
            ],
          ),
        ),
      );
    }
    return ComparisonView(
      ticker: DashTicker(
        title: null,
        ticker1: link.tickers.first,
        ticker2: link.baseCount == 2 ? link.tickers[1] : null,
      ),
      initialExtraTickers: link.tickers.skip(link.baseCount).toList(),
      initialRange: ComparisonRange.values.byName(link.range),
      yearOffsetMinutes: link.yearOffsetMinutes,
      onClose: () => context.go('/'),
    );
  },
);

class ComparisonView extends StatefulWidget {
  const ComparisonView({
    super.key,
    required this.ticker,
    required this.onClose,
    this.initialExtraTickers = const [],
    this.initialRange = ComparisonRange.sevenDays,
    this.yearOffsetMinutes,
  });

  final DashTicker ticker;
  final VoidCallback onClose;
  final List<String> initialExtraTickers;
  final ComparisonRange initialRange;
  final int? yearOffsetMinutes;

  @override
  State<ComparisonView> createState() => _ComparisonViewState();
}

class _ComparisonViewState extends State<ComparisonView> {
  final _tickerInput = TextEditingController();
  final _extraTickers = <String>[];
  ComparisonRange _range = ComparisonRange.sevenDays;
  List<ComparisonSeries>? _series;
  String? _error;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _extraTickers.addAll(widget.initialExtraTickers);
    _range = widget.initialRange;
    _load();
  }

  @override
  void dispose() {
    _requestId++;
    _tickerInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    final range = _range;
    final tickers = [...comparisonTickers(widget.ticker), ..._extraTickers];
    setState(() {
      _loading = true;
      _error = null;
      _series = null;
    });

    List<Result<CustomTickerResult>> results;
    try {
      results = await Future.wait(
        tickers.map(
          (ticker) => ServerApi()
              .fetchCustomTicker(
                DashTicker(title: null, ticker1: ticker, ticker2: null),
                range.apiRange,
              )
              .timeout(
                const Duration(seconds: 20),
                onTimeout: () => Result.error(Exception('Timed out')),
              ),
        ),
      );
    } catch (error, stackTrace) {
      _log.severe('Unexpected error loading comparison', error, stackTrace);
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Could not load comparison data. Try again.';
      });
      return;
    }
    if (!mounted || id != _requestId) return;
    final series = <ComparisonSeries>[];
    for (var i = 0; i < results.length; i++) {
      final label = tickers[i];
      switch (results[i]) {
        case Ok<CustomTickerResult>(:final value):
          series.add(
            ComparisonSeries(
              label: label,
              prices: value.priceData,
              dividends: value.dividendData,
              currency: value.currency,
              sources: value.sources,
            ),
          );
        case Error<CustomTickerResult>(:final error):
          setState(() {
            _loading = false;
            _error = '$label: ${describeLoadError(error)}';
          });
          return;
      }
    }

    final now = DateTime.now();
    final cutoff =
        range == ComparisonRange.yearToDate
            ? comparisonYearStart(
              now,
              widget.yearOffsetMinutes ??
                  DateTime(now.year).timeZoneOffset.inMinutes,
            )
            : null;
    final normalized = normalizeComparison(
      series,
      cutoff: cutoff,
      window:
          range == ComparisonRange.oneDay ? const Duration(hours: 24) : null,
    );
    setState(() {
      _loading = false;
      if (normalized == null) {
        _error =
            'Not enough overlapping price data to compare these tickers. '
            'Try another range or remove a ticker.';
      } else {
        _series = normalized;
      }
    });
  }

  void _addTicker() {
    final ticker = _tickerInput.text.trim().toUpperCase();
    final existing = [...comparisonTickers(widget.ticker), ..._extraTickers];
    if (existing.length >= maxComparisonTickers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Up to $maxComparisonTickers tickers can be compared.'),
        ),
      );
      return;
    }
    if (ticker.isEmpty ||
        existing.any((value) => value.toUpperCase() == ticker)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ticker.isEmpty ? 'Enter a ticker symbol.' : 'Ticker already added.',
          ),
        ),
      );
      return;
    }
    if (ticker.length > 128 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(ticker)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid ticker symbol.')));
      return;
    }
    setState(() {
      _extraTickers.add(ticker);
      _tickerInput.clear();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    String formatEndpoint(DateTime date) =>
        _range == ComparisonRange.oneDay
            ? DateFormat.yMMMd().add_Hm().format(date.toLocal())
            : DateFormat.yMMMd().format(date);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relative performance'),
        actions: [
          Tooltip(
            message: 'Share comparison',
            child: ShareButton(
              uri: Uri(path: '/compare'),
              queryParams: {
                'tickers': jsonEncode([
                  ...comparisonTickers(widget.ticker),
                  ..._extraTickers,
                ]),
                'baseCount': '${comparisonTickers(widget.ticker).length}',
                'range': _range.name,
                'yearOffset':
                    '${widget.yearOffsetMinutes ?? DateTime(DateTime.now().year).timeZoneOffset.inMinutes}',
              },
            ),
          ),
        ],
        leading: IconButton(
          tooltip: 'Back to chart',
          onPressed: widget.onClose,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final range in ComparisonRange.values)
                  ChoiceChip(
                    label: Text(range.label),
                    selected: _range == range,
                    onSelected: (_) {
                      if (_range == range) return;
                      setState(() => _range = range);
                      _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tickerInput,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Add ticker symbol',
                      hintText: 'e.g. AAPL',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTicker(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _addTicker, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (
                  var i = 0;
                  i < comparisonTickers(widget.ticker).length;
                  i++
                )
                  Chip(
                    avatar: Icon(
                      Icons.circle,
                      size: 12,
                      color: comparisonColors[i % comparisonColors.length],
                    ),
                    label: Text(comparisonTickers(widget.ticker)[i]),
                  ),
                for (var i = 0; i < _extraTickers.length; i++)
                  InputChip(
                    avatar: Icon(
                      Icons.circle,
                      size: 12,
                      color:
                          comparisonColors[(comparisonTickers(
                                    widget.ticker,
                                  ).length +
                                  i) %
                              comparisonColors.length],
                    ),
                    label: Text(_extraTickers[i]),
                    onDeleted: () {
                      setState(() => _extraTickers.removeAt(i));
                      _load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null) ...[
              Text(_error!, key: const ValueKey('comparison-error')),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ] else if (series != null) ...[
              Text(
                'Indexed to 100 at each series’ first available point in '
                'the common window. Observations are evenly spaced, not '
                'elapsed time; price changes exclude dividends. '
                'The horizontal line marks the starting value (0%).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(height: 260, child: _chart(series)),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatEndpoint(
                        series
                            .map((item) => item.prices.first.date)
                            .reduce((a, b) => a.isBefore(b) ? a : b),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      formatEndpoint(
                        series
                            .map((item) => item.prices.last.date)
                            .reduce((a, b) => a.isAfter(b) ? a : b),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < series.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: comparisonColors[i % comparisonColors.length],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${series[i].label} · '
                          '${series[i].prices.last.amount >= 100 ? '+' : ''}'
                          '${(series[i].prices.last.amount - 100).toStringAsFixed(2)}%',
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in series)
                Text(
                  '${item.label}: last point shown '
                  '${DateFormat.yMMMd().add_Hm().format(item.prices.last.date.toLocal())}'
                  '${item.sources.isEmpty ? '' : ' · ${item.sources.map(sourceLabel).join(', ')}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 20),
              Text('Dividends', style: Theme.of(context).textTheme.titleMedium),
              const Text(
                'Dots mark dividends on matching price dates. Amounts are '
                'per share in the source currency.',
              ),
              if (series.every((item) => item.dividends.isEmpty))
                const Text('No dividends in this period.'),
              for (final item in series)
                for (final dividend in item.dividends)
                  Text(
                    '${item.label} · ${DateFormat.yMMMd().format(dividend.date)}'
                    ' · ${formatPrice(dividend.amount, currencyChar: '', space: '')} '
                    '${item.currency}',
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chart(List<ComparisonSeries> series) {
    final timeline = ComparisonTimeline(series);
    final amounts = series.expand((item) => item.prices).map((p) => p.amount);
    final low = amounts.reduce(math.min);
    final high = amounts.reduce(math.max);
    final padding = low == high ? 1.0 : (high - low) * 0.05;
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final markerIndices = [
      for (final item in series)
        <int>{
          for (final event in item.dividends)
            if (item.prices.indexWhere(
                  (price) => sameDay(event.date, price.date),
                ) >=
                0)
              item.prices.indexWhere(
                (price) => sameDay(event.date, price.date),
              ),
        },
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (timeline.length - 1).toDouble(),
        minY: low - padding,
        maxY: high + padding,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: false,
          horizontalLines: [
            HorizontalLine(
              y: comparisonBaseline,
              color: Theme.of(context).colorScheme.outline,
              strokeWidth: 1,
              dashArray: [5, 4],
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget:
                  (value, _) => Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10),
                  ),
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          for (var i = 0; i < series.length; i++)
            LineChartBarData(
              color: comparisonColors[i % comparisonColors.length],
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                checkToShowDot:
                    (spot, _) => markerIndices[i].any(
                      (index) =>
                          timeline.position(series[i].prices[index].date) ==
                          spot.x.round(),
                    ),
              ),
              spots: [
                for (var j = 0; j < series[i].prices.length; j++)
                  if (j == 0 ||
                      j == series[i].prices.length - 1 ||
                      j % math.max(1, (series[i].prices.length / 800).ceil()) ==
                          0 ||
                      markerIndices[i].contains(j))
                    FlSpot(
                      timeline.position(series[i].prices[j].date).toDouble(),
                      series[i].prices[j].amount,
                    ),
              ],
            ),
        ],
      ),
    );
  }
}
