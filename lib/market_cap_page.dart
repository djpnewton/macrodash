import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:macrodash_models/models.dart';

import 'api.dart';
import 'option_buttons.dart';
import 'result.dart';
import 'sparkline.dart';

final Logger log = Logger('market_cap_page');

enum SparklineStatus { loading, error, success }

class MarketCapPage extends StatefulWidget {
  const MarketCapPage({super.key, required this.title});

  final String title;
  final MarketCap defaultMarket = MarketCap.metals;

  @override
  State<MarketCapPage> createState() => _MarketCapPageState();
}

class _MarketCapPageState extends State<MarketCapPage> {
  final ServerApi _api = ServerApi();
  MarketCapSeries? _marketCapSeries;
  bool _isLoading = true;
  late MarketCap _selectedMarket;
  Map<String, SparklineStatus> _sparklineStatus = {};
  Map<String, YahooSparklineData> _sparklineData = {};

  @override
  void initState() {
    super.initState();
    // Initialize with the default market
    _selectedMarket = widget.defaultMarket;
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    final result = await _api.fetchMarketCapSeries(_selectedMarket);
    switch (result) {
      case Ok():
        _marketCapSeries = result.value;
      case Error():
        // show snackbar
        if (mounted) {
          var snackBar = SnackBar(
            content: Text('Unable to get data! - ${result.error}'),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
    }

    setState(() {
      _isLoading = false;
      _marketCapSeries = _marketCapSeries;
      if (_marketCapSeries == null) {
        return;
      }
    });
  }

  void _marketSelect(MarketCap market) {
    setState(() {
      _selectedMarket = market;
      _fetchData();
    });
  }

  String _formatMarketCap(double marketCap) {
    if (marketCap >= 1e12) {
      return '\$${(marketCap / 1e12).toStringAsFixed(2)} T';
    } else if (marketCap >= 1e9) {
      return '\$${(marketCap / 1e9).toStringAsFixed(2)} B';
    } else if (marketCap >= 1e6) {
      return '\$${(marketCap / 1e6).toStringAsFixed(2)} M';
    } else {
      return '\$${marketCap.toStringAsFixed(2)}';
    }
  }

  String _formatPrice(double price) {
    if (price >= 1e6) {
      return '\$${(price / 1e6).toStringAsFixed(2)} M';
    } else if (price >= 1e3) {
      return '\$${(price / 1e3).toStringAsFixed(2)} K';
    } else {
      return '\$${price.toStringAsFixed(2)}';
    }
  }

  Text _formatPriceChange(double priceChange) {
    if (priceChange > 0) {
      return Text(
        '${priceChange.toStringAsFixed(2)}%',
        style: TextStyle(color: Colors.green),
      );
    } else {
      return Text(
        '${priceChange.toStringAsFixed(2)}%',
        style: TextStyle(color: Colors.red),
      );
    }
  }

  Widget _sparkline(
    String ticker,
    List<num?>? sparkline,
    List<int>? timestamps,
  ) {
    if (sparkline == null) {
      if (_sparklineStatus.keys.contains(ticker)) {
        switch (_sparklineStatus[ticker]!) {
          case SparklineStatus.loading:
            return const CircularProgressIndicator();
          case SparklineStatus.error:
            return const Text('No data');
          case SparklineStatus.success:
            return SizedBox(
              width: 100,
              height: 25,
              child: CustomPaint(
                painter: SparkPainter(
                  _sparklineData[ticker]!.sparkline,
                  timestamps: _sparklineData[ticker]!.sparklineTimestamps,
                ),
              ),
            );
        }
      }
      // make a request to get the sparkline
      _sparklineStatus[ticker] = SparklineStatus.loading;
      _api.fetchYahooSparkline(ticker).then((result) {
        switch (result) {
          case Ok():
            _sparklineStatus[ticker] = SparklineStatus.success;
            _sparklineData[ticker] = result.value;
          case Error():
            _sparklineStatus[ticker] = SparklineStatus.error;
        }
        setState(() {
          _sparklineStatus = _sparklineStatus;
          _sparklineData = _sparklineData;
        });
      });
      return const CircularProgressIndicator();
    } else {
      // If the sparkline is already available, use it
      return SizedBox(
        width: 100,
        height: 25,
        child: CustomPaint(
          painter: SparkPainter(sparkline, timestamps: timestamps),
        ),
      );
    }
  }

  Widget _marketCapRow(int index, {bool header = false}) {
    final asset = _marketCapSeries!.data[index];
    final marketCap = _formatMarketCap(asset.marketCap);
    final price = _formatPrice(asset.price);
    final priceChange = _formatPriceChange(asset.priceChangePercent24h);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 50),
              child:
                  header
                      ? Center(
                        child: Text(
                          'Rank',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                      : Text('${index + 1}', textAlign: TextAlign.right),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 200),
              child:
                  header
                      ? Center(
                        child: Text(
                          'Name',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                      : Row(
                        children: [
                          (asset.image != null)
                              ? asset.image!.endsWith('.svg')
                                  ? SvgPicture.network(
                                    asset.image!,
                                    width: 24,
                                    height: 24,
                                  )
                                  : Image.network(
                                    asset.image!,
                                    width: 24,
                                    height: 24,
                                  )
                              : Image.asset(
                                'assets/coin.png',
                                width: 24,
                                height: 24,
                              ),
                          const SizedBox(width: 8),
                          Text(asset.name),
                        ],
                      ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
              child:
                  header
                      ? Center(
                        child: Text(
                          'Market Cap',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                      : Center(child: Text(marketCap)),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
              child:
                  header
                      ? Center(
                        child: Text(
                          'Price',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                      : Center(child: Text(price)),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
              child:
                  header
                      ? Center(
                        child: Text(
                          '24h',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                      : Center(child: priceChange),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
              child:
                  header
                      ? Center(
                        child: Text(
                          'Price (1w)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                      : Center(
                        child: _sparkline(
                          asset.ticker,
                          asset.sparkline,
                          asset.sparklineTimestamps,
                        ),
                      ),
            ),
            //TODO: reformat for smaller screens
          ],
        ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final smallWidth = size.width < 600;
    final smallHeight = size.height < 400;
    final hPadding = smallWidth ? 2.0 : 16.0;
    final vPadding = smallHeight ? 2.0 : 16.0;
    final popouts = smallWidth || smallHeight;
    final optionsSide = smallHeight;
    final fullscreenButton = FullscreenButton();
    final categoryButtons = OptionButtons<MarketCap>(
      popoutTitle: 'Category',
      selectedOption: _selectedMarket,
      values: MarketCap.values,
      onOptionSelected: _marketSelect,
      labels: marketCapLabels,
      popout: popouts,
    );
    final Widget options = switch (optionsSide) {
      true => Padding(
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: vPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [categoryButtons],
        ),
      ),
      false => Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [categoryButtons],
        ),
      ),
    };
    final chart =
        _isLoading
            ? Expanded(child: const Center(child: CircularProgressIndicator()))
            : _marketCapSeries == null
            ? Expanded(child: const Center(child: Text('No data available.')))
            :
            // Line Chart
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hPadding,
                  vertical: vPadding,
                ),
                child: ListView.builder(
                  itemCount: _marketCapSeries!.data.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _marketCapRow(index, header: true);
                    }
                    return _marketCapRow(index - 1);
                  },
                ),
              ),
            );
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} Data Visualization'),
        actions: [if (kIsWeb) fullscreenButton],
      ),
      body:
          optionsSide
              ? Row(children: [options, chart])
              : Column(children: [options, chart]),
    );
  }
}
