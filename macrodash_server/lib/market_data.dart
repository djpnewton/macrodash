import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_server/abstract_downloader.dart';

/// A class that handles downloading and parsing data from various sources.
/// It provides methods to download and parse data related to M2 money supply,
/// exchange rates, and sovereign debt.
class MarketData extends AbstractDownloader {
  /// Creates an instance of [MarketData]
  MarketData();

  /// Yahoo data source
  static const String yahooSource = 'https://finance.yahoo.com/';
  final Logger _log = Logger('MarketData');

  /// Fetches and parses the Index data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> indexData(
    Enum index,
    DataRange range,
  ) async {
    // convert index string to yahoo finance ticker
    var ticker = '';
    if (index is MarketIndexUsa) {
      switch (index) {
        case MarketIndexUsa.sp500:
          ticker = '^GSPC';
        case MarketIndexUsa.nasdaq:
          ticker = '^IXIC';
        case MarketIndexUsa.dowjones:
          ticker = '^DJI';
        case MarketIndexUsa.russell2000:
          ticker = '^RUT';
        case MarketIndexUsa.vix:
          ticker = '^VIX';
        case MarketIndexUsa.dxy:
          ticker = 'DX-Y.NYB';
      }
    } else if (index is MarketIndexEurope) {
      switch (index) {
        case MarketIndexEurope.ftse100:
          ticker = '^FTSE';
        case MarketIndexEurope.dax:
          ticker = '^GDAXI';
        case MarketIndexEurope.cac40:
          ticker = '^FCHI';
        case MarketIndexEurope.ibex35:
          ticker = '^IBEX';
        case MarketIndexEurope.euroStocks50:
          ticker = '^STOXX50E';
      }
    } else if (index is MarketIndexAsia) {
      switch (index) {
        case MarketIndexAsia.nikkei225:
          ticker = '^N225';
        case MarketIndexAsia.hangSeng:
          ticker = '^HSI';
        case MarketIndexAsia.sse:
          ticker = '000001.SS';
        case MarketIndexAsia.sensex:
          ticker = '^BSESN';
        case MarketIndexAsia.nifty50:
          ticker = '^NSEI';
      }
    } else {
      _log.severe('Unknown index type: $index');
      return null;
    }
    // convert the range enum to a string
    final rangeStr = switch (range) {
      DataRange.oneDay => '1d',
      DataRange.fiveDays => '5d',
      DataRange.oneMonth => '1mo',
      DataRange.threeMonths => '3mo',
      DataRange.sixMonths => '6mo',
      DataRange.oneYear => '1y',
      DataRange.twoYears => '2y',
      DataRange.fiveYears => '5y',
      DataRange.tenYears => '10y',
      DataRange.max => 'max',
    };
    // Fetch the data from Yahoo Finance
    final url = 'https://query2.finance.yahoo.com/v8/finance/chart/$ticker';
    final data = await downloadFile(url, {'interval': '1d', 'range': rangeStr});
    if (data == null) {
      _log.warning('Failed to download data for ticker: $ticker');
      return null;
    }
    // Parse the data into a list of AmountEntry objects
    final parsedData = jsonDecode(data) as Map<String, dynamic>;
    final entries = <AmountEntry>[];
    final timestamps =
        // ignore: avoid_dynamic_calls
        parsedData['chart']['result'][0]['timestamp'] as List<dynamic>;
    // ignore: avoid_dynamic_calls
    final closePrices = parsedData['chart']['result'][0]['indicators']['quote']
        [0]['close'] as List<dynamic>;
    for (var i = 0; i < timestamps.length; i++) {
      final timestamp = timestamps[i] as int;
      final closePrice = closePrices[i] as double?;
      if (closePrice == null) {
        continue; // Skip if close price is null
      }
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      entries.add(AmountEntry(date: date, amount: closePrice));
    }
    return entries;
  }
}
