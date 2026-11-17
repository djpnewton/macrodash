import 'dart:async';

import 'package:flutter/material.dart';
import 'package:macrodash_models/models.dart';
import 'package:logging/logging.dart';
import 'package:go_router/go_router.dart';

import 'settings.dart';
import 'sparkline.dart';
import 'theme.dart';
import 'fixed_height_grid_delegate.dart';
import 'ticker_search.dart';
import 'api.dart';
import 'result.dart';
import 'helper.dart';
import 'amount_series_page.dart';
import 'config.dart';
import 'freshness.dart';

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

  final titleController = TextEditingController();
  final controller1 = TextEditingController();
  final controller2 = TextEditingController();
  final SearchController searchController1 = SearchController();
  final SearchController searchController2 = SearchController();

  @override
  void initState() {
    super.initState();
    _ticker = widget.ticker;
    titleController.text = _ticker.title ?? '';
    titleController.addListener(_updateTicker);
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
    titleController.dispose();
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
        title: titleController.text.isEmpty ? null : titleController.text,
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
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => titleController.clear(),
                    icon: Icon(Icons.clear),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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

enum DashState {
  /// First load, showing the configured ticker while data is fetched.
  loading,

  /// First load failed, nothing to show.
  error,

  /// Showing data while a reload is in flight.
  reloading,

  /// Showing data that is older than the refresh interval, or whose last
  /// reload failed.
  stale,

  /// Showing current data.
  loaded;

  bool get hasData => this != loading && this != error;
}

class DashCard extends StatefulWidget {
  final DashTicker ticker;
  final Widget dragHandle;
  final VoidCallback? onConfig;
  final VoidCallback? onRemove;
  final VoidCallback? onTitleTap;

  /// Changing this reloads the data in the background, keeping the current
  /// data visible meanwhile.
  final int refreshToken;

  const DashCard({
    super.key,
    required this.ticker,
    required this.dragHandle,
    this.refreshToken = 0,
    this.onConfig,
    this.onRemove,
    this.onTitleTap,
  });

  @override
  State<DashCard> createState() => _DashCardState();
}

class _DashCardState extends State<DashCard> with TickerProviderStateMixin {
  DashState _state = DashState.loading;
  CustomTickerResult? _customTickerResult;
  bool _show7d = false;

  Duration get _window =>
      _show7d ? const Duration(days: 7) : const Duration(hours: 24);
  String get _windowLabel => _show7d ? '7d' : '24h';

  static const _reloadTimeout = Duration(seconds: 20);

  int _loadId = 0;
  DateTime _loadedAt = DateTime.now();
  Timer? _staleTimer;

  /// Why the last load failed, or null when it succeeded.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _staleTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkStale(),
    );
    _loadTickerData();
  }

  /// Data goes stale after the auto-refresh interval (15 minutes when
  /// auto-refresh is off); a failed reload marks it stale immediately.
  Future<void> _checkStale() async {
    final minutes = Settings.loadAutoRefreshMinutes(await Settings.getPrefs());
    if (!mounted || !_state.hasData) return;
    final limit = Duration(minutes: minutes > 0 ? minutes : 15);
    final expired =
        _state == DashState.loaded &&
        DateTime.now().difference(_loadedAt) >= limit;
    // Rebuild either way so the "updated ... ago" text keeps up.
    setState(() {
      if (expired) _state = DashState.stale;
    });
  }

  // Creeps towards 90% while waiting, then fills up when the request is done.
  late final AnimationController _progress = AnimationController(vsync: this);
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _staleTimer?.cancel();
    _progress.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DashCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadTickerData();
    }
  }

  Future<void> _loadTickerData() async {
    final id = ++_loadId;
    final hasData = _state.hasData;
    if (hasData) {
      setState(() => _state = DashState.reloading);
      _progress
        ..value = 0
        ..animateTo(
          0.9,
          duration: const Duration(seconds: 10),
          curve: Curves.easeOut,
        );
    } else {
      setState(() => _state = DashState.loading);
    }
    Result<CustomTickerResult> result;
    try {
      result = await ServerApi()
          .fetchCustomTicker(widget.ticker, DataRange.sevenDays)
          .timeout(_reloadTimeout);
    } on TimeoutException {
      result = Result.error(Exception('Timed out'));
    } catch (e) {
      // Never leave the card spinning on an unexpected error.
      _log.severe('Failed to load ${widget.ticker.ticker1}: $e');
      result = Result.error(Exception(e));
    }
    // A newer load superseded this one.
    if (!mounted || id != _loadId) return;
    switch (result) {
      case Ok():
        setState(() {
          _customTickerResult = (result as Ok<CustomTickerResult>).value;
          _loadedAt = DateTime.now();
          _loadError = null;
          if (!hasData) _state = DashState.loaded;
        });
        if (hasData) {
          await _progress.animateTo(
            1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
          if (!mounted || id != _loadId) return;
          setState(() => _state = DashState.loaded);
        }
        _shine.forward(from: 0);
      case Error():
        _progress.stop();
        setState(() {
          _loadError = describeLoadError(
            (result as Error<CustomTickerResult>).error,
          );
          // Keep showing the old data if a reload fails.
          _state = hasData ? DashState.stale : DashState.error;
        });
    }
  }

  /// Data within [_window] of the last entry.
  List<AmountEntry> _windowData(List<AmountEntry> data) {
    if (data.isEmpty) return const [];
    final cutoff = data.last.date.subtract(_window);
    return data.where((entry) => entry.date.isAfter(cutoff)).toList();
  }

  double _calculateChange(List<AmountEntry> data) {
    final windowData = _windowData(data);
    if (windowData.isEmpty) return 0.0;
    final firstValue = windowData.first.amount;
    final lastValue = windowData.last.amount;
    if (firstValue == 0) return 0.0; // avoid division by zero
    return ((lastValue - firstValue) / firstValue) * 100;
  }

  YahooSparklineData _calculateSparklineValues(List<AmountEntry> data) {
    final windowData = _windowData(data);
    return YahooSparklineData(
      sparkline: windowData.map((entry) => entry.amount).toList(),
      sparklineTimestamps:
          windowData.map((entry) => entry.date.millisecondsSinceEpoch).toList(),
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
          style: TextStyle(
            fontSize: fontSizeBottom,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              bottom,
              style: TextStyle(
                fontSize: fontSizeBottom,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  /// Source, newest price time and fetch age of the data on screen.
  String _freshnessText() {
    final result = _customTickerResult!;
    return freshnessSummary(
      sources: result.sources,
      lastPoint: result.priceData.last.date,
      fetchedAt: _loadedAt,
      now: DateTime.now(),
      error: _loadError,
    );
  }

  List<Widget> _buildPriceWidgets(bool useColumn) {
    final changePct = _calculateChange(_customTickerResult!.priceData);
    final isUp = changePct >= 0;
    final appColors = context.appColors;
    final changeColor = isUp ? appColors.gain : appColors.loss;
    final changePrefix = isUp ? '+' : '';
    final boxWidth = useColumn ? 80.0 : 65.0;
    final boxHeight = useColumn ? 25.0 : 35.0;
    final fontSize = useColumn ? 14.0 : 16.0;

    final priceBox = SizedBox(
      width: boxWidth,
      height: boxHeight,
      child:
          useColumn
              ? _rowText(
                formatPrice(
                  _customTickerResult!.priceData.last.amount,
                  currencyChar: '',
                  space: '',
                ),
                fontSize,
                _customTickerResult!.currency,
                8,
              )
              : _stackText(
                formatPrice(
                  _customTickerResult!.priceData.last.amount,
                  currencyChar: '',
                  space: '',
                ),
                fontSize,
                _customTickerResult!.currency,
                8,
              ),
    );
    final price = Tooltip(
      key: const ValueKey('freshness-tooltip'),
      message: _freshnessText(),
      // Tap works on touch screens, where there is no hover.
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      child: priceBox,
    );
    final changeBox = SizedBox(
      width: boxWidth,
      height: boxHeight,
      child:
          useColumn
              ? _rowText(
                '$changePrefix${changePct.toStringAsFixed(2)}%',
                fontSize,
                _windowLabel,
                8,
                topColor: changeColor,
              )
              : _stackText(
                '$changePrefix${changePct.toStringAsFixed(2)}%',
                fontSize,
                _windowLabel,
                8,
                topColor: changeColor,
              ),
    );
    final change = Tooltip(
      message: 'Toggle 24h / 7d',
      child: InkWell(
        onTap: () => setState(() => _show7d = !_show7d),
        child: changeBox,
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

  void _showLargeSparkline(
    BuildContext context,
    YahooSparklineData sparklineData,
  ) {
    assert(_customTickerResult != null, 'Custom ticker result is null');
    final result = _customTickerResult!;
    final title = widget.ticker.title ?? result.shortName;
    showLargeSparkline(
      context,
      title: title,
      subtitle: result.longName == title ? null : result.longName,
      priceText: formatPrice(
        result.priceData.last.amount,
        currencyChar: '',
        space: '',
      ),
      secondaryText: result.currency,
      changePercent24h: _calculateChange(result.priceData),
      changeLabel: _windowLabel,
      note: _show7d ? 'Last 7 days' : 'Last 24 hours',
      freshness: _freshnessText().replaceAll('\n', ' · '),
      values: sparklineData.sparkline,
      timestamps: sparklineData.sparklineTimestamps,
    );
  }

  /// A card without data yet
  Widget _buildPlaceholderCard(Widget child) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(child: child),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(width: 14, height: 35, child: widget.dragHandle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      // Keeps the message clear of the drag handle.
      padding: const EdgeInsets.only(left: 32, right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Error loading ticker data'),
                if (_loadError != null)
                  Text(
                    _loadError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _loadTickerData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    final ticker = widget.ticker;
    final symbols =
        ticker.ticker2 == null || ticker.ticker2!.isEmpty
            ? ticker.ticker1
            : '${ticker.ticker1} / ${ticker.ticker2}';
    final title = ticker.title;
    final hasTitle = title != null && title.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 35,
              child: Center(child: widget.dragHandle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasTitle ? title : symbols,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (hasTitle && title != symbols)
                    Text(
                      symbols,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTickerCard(BuildContext context) {
    assert(_customTickerResult != null, 'Custom ticker result is null');
    final result = _customTickerResult!;
    final sparklineData = _calculateSparklineValues(result.priceData);
    final useColumn = MediaQuery.of(context).size.width < 400;
    final title = widget.ticker.title ?? result.shortName;
    // A subtitle that repeats the title adds nothing.
    final subtitle = result.longName == title ? '' : result.longName;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Grab handle
                SizedBox(
                  width: 14,
                  height: 35,
                  child: Center(child: widget.dragHandle),
                ),
                const SizedBox(width: 2),
                // Stock name
                SizedBox(
                  width: 84,
                  height: 35,
                  child: _stackText(
                    title,
                    16,
                    subtitle,
                    8,
                    topWidget: TextButton(
                      style: TextButton.styleFrom(
                        // The title block lost its handle width, so drop the
                        // button padding to keep the same text space.
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: widget.onTitleTap,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        softWrap: false,
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
                Tooltip(
                  message: 'Show larger chart',
                  child: InkWell(
                    onTap: () => _showLargeSparkline(context, sparklineData),
                    child: SizedBox(
                      width: 110,
                      height: 25,
                      child: CustomPaint(
                        painter: SparkPainter(
                          sparklineData.sparkline,
                          timestamps: sparklineData.sparklineTimestamps,
                          colorUp: context.appColors.gain,
                          colorDown: context.appColors.loss,
                        ),
                      ),
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
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loadError != null)
            Positioned(
              left: 0,
              top: 0,
              child: Tooltip(
                message: 'Showing older data. Reload failed: $_loadError',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                child: Padding(
                  // A larger tap target around the small icon.
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _state == DashState.reloading ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedBuilder(
                animation: _progress,
                builder:
                    (context, _) => LinearProgressIndicator(
                      value: _progress.value,
                      minHeight: 2,
                    ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _state == DashState.stale ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: ColoredBox(color: Colors.grey.withValues(alpha: 0.25)),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _shine,
                builder:
                    (context, _) =>
                        _shine.isAnimating
                            ? CustomPaint(painter: _ShinePainter(_shine.value))
                            : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case DashState.loading:
        return _buildLoadingCard();
      case DashState.error:
        return _buildPlaceholderCard(_buildErrorContent());
      case DashState.reloading:
      case DashState.stale:
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

class _DashPanelState extends State<DashPanel> with WidgetsBindingObserver {
  int _refreshToken = 0;
  DateTime _lastRefresh = DateTime.now();
  DashTickers _tickers = DashTickers(tickers: []);
  // Hidden until the stored preference is known, to avoid a flash.
  bool _showTips = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTickers();
    _loadTips();
  }

  Future<void> _loadTips() async {
    final dismissed = Settings.loadTipsDismissed(await Settings.getPrefs());
    if (!mounted) return;
    setState(() => _showTips = !dismissed);
  }

  void _dismissTips() {
    setState(() => _showTips = false);
    Settings.saveTipsDismissed(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfStale();
    }
  }

  Future<void> _refreshIfStale() async {
    final minutes = Settings.loadAutoRefreshMinutes(await Settings.getPrefs());
    if (!mounted || minutes <= 0) return;
    if (DateTime.now().difference(_lastRefresh) >= Duration(minutes: minutes)) {
      await _refreshTickers();
    }
  }

  Future<void> _loadTickers() async {
    final dashTickers = Settings.loadDashTickers(await Settings.getPrefs());
    setState(() {
      _tickers = dashTickers;
    });
  }

  Future<void> _refreshTickers() async {
    setState(() {
      _lastRefresh = DateTime.now();
      _refreshToken++;
    });
  }

  /// Index of the card currently being dragged, if any.
  int? _draggingIndex;

  void _setDraggingIndex(int? index) {
    if (!mounted) return;
    setState(() => _draggingIndex = index);
  }

  /// Moves the ticker at [from] into the position of the ticker at [to].
  void _moveTicker(int from, int to) {
    if (from == to) return;
    final tickers = List<DashTicker>.of(_tickers.tickers);
    final ticker = tickers.removeAt(from);
    tickers.insert(to, ticker);
    _log.info('Moved ${ticker.ticker1} to position ${to + 1}');
    setState(() {
      _tickers = DashTickers(tickers: tickers);
    });
    // save the new order to settings
    Settings.saveDashTickers(_tickers);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size;
    const cardWidth = 400.0;
    final columns = (width.width / cardWidth).floor();

    return Column(
      children: [
        if (_showTips) _DashTips(onDismiss: _dismissTips),
        Expanded(child: _buildGrid(columns)),
      ],
    );
  }

  Widget _buildGrid(int columns) {
    return RefreshIndicator(
      key: widget.refreshKey,
      onRefresh: _refreshTickers,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _tickers.tickers.length + 1,
        // Keep each card's state (and its loaded data) when the order changes.
        findChildIndexCallback: (key) {
          if (key is! ObjectKey) return null;
          final index = _tickers.tickers.indexWhere(
            (ticker) => identical(ticker, key.value),
          );
          return index < 0 ? null : index;
        },
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
          crossAxisCount: columns > 0 ? columns : 1,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          height: 75.0,
        ),
        itemBuilder:
            (context, index) =>
                index == _tickers.tickers.length
                    ? _buildAddTicker(context)
                    : _buildTickerCell(context, index),
      ),
    );
  }

  Widget _buildAddTicker(BuildContext context) {
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
                  ticker: DashTicker(title: null, ticker1: '', ticker2: ''),
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

  /// A grab handle that drags the card it belongs to.
  Widget _buildDragHandle(BuildContext context, int index, DashTicker ticker) {
    return MouseRegion(
      cursor:
          _draggingIndex == index
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
      child: Tooltip(
        message: 'Drag to reorder',
        // A tap trigger keeps the long press free for the drag gesture.
        triggerMode: TooltipTriggerMode.tap,
        child: Draggable<int>(
          data: index,
          feedback: _DragFeedback(ticker: ticker),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: () => _setDraggingIndex(index),
          onDragEnd: (_) => _setDraggingIndex(null),
          child: Icon(
            Icons.drag_indicator,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// A ticker card that can be dragged onto another card to take its place.
  Widget _buildTickerCell(BuildContext context, int index) {
    final ticker = _tickers.tickers[index];
    return DragTarget<int>(
      key: ObjectKey(ticker),
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => _moveTicker(details.data, index),
      builder: (context, candidateData, rejectedData) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: 2,
              color:
                  candidateData.isEmpty
                      ? Colors.transparent
                      : Theme.of(context).colorScheme.primary,
            ),
          ),
          child: Opacity(
            opacity: _draggingIndex == index ? 0.35 : 1,
            child: _buildDashCard(context, index),
          ),
        );
      },
    );
  }

  Widget _buildDashCard(BuildContext context, int index) {
    final ticker = _tickers.tickers[index];
    return DashCard(
      key: ObjectKey(ticker),
      refreshToken: _refreshToken,
      ticker: ticker,
      dragHandle: _buildDragHandle(context, index, ticker),
      onTitleTap: () async {
        _log.info('Tapped on ${ticker.ticker1}');
        log.info('Navigating to Ticker');
        context.goNamed(
          AppPage.ticker.name,
          queryParameters: {
            'title': ticker.title ?? '',
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
            _log.info('Removing ${ticker.ticker1}');
            setState(() {
              _tickers = DashTickers(
                tickers: _tickers.tickers.where((t) => t != ticker).toList(),
              );
            });
            // save the new list to settings
            Settings.saveDashTickers(_tickers);
          }
        });
      },
      onConfig: () {
        _log.info('Configuring ${ticker.ticker1}');
        showDialog(
          context: context,
          builder: (context) {
            return TickerConfig(
              ticker: ticker,
              onSave: (updated) {
                setState(() {
                  _tickers = DashTickers(
                    tickers:
                        _tickers.tickers
                            .map((t) => t == ticker ? updated : t)
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
  }
}

/// First-run hints about the dashboard gestures, dismissed for good once closed.
class _DashTips extends StatelessWidget {
  const _DashTips({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('dash-tips'),
      color: colors.secondaryContainer,
      margin: const EdgeInsets.fromLTRB(5, 5, 5, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap the percentage change on a card to switch between 24h and '
                '7d, tap the price to see its source and age, tap the name to '
                'open a full chart, and drag the handle to reorder. Add a '
                'second ticker to compare two assets. Your watchlist is saved '
                'on this device.',
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Dismiss tips',
              color: colors.onSecondaryContainer,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft diagonal highlight sweeping left to right as [t] goes 0 -> 1.
class _ShinePainter extends CustomPainter {
  _ShinePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.width * 0.35;
    final x = -band + (size.width + band) * Curves.easeInOut.transform(t);
    final paint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(x, 0, band, size.height));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ShinePainter oldDelegate) => oldDelegate.t != t;
}

/// The ghost that follows the pointer while a ticker card is being dragged.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.ticker});

  final DashTicker ticker;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = ticker.title ?? ticker.ticker1;
    final ticker2 = ticker.ticker2;
    final symbols =
        ticker2 == null || ticker2.isEmpty
            ? ticker.ticker1
            : '${ticker.ticker1} vs $ticker2';
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_indicator,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 6),
            Text(
              symbols,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
