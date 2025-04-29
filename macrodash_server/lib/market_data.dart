import 'dart:convert';

import 'package:html/parser.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_server/abstract_downloader.dart';

/// A class that handles downloading and parsing data from various sources.
/// It provides methods to download and parse data related to stock indices,
/// market capitalization
class MarketData extends AbstractDownloader {
  /// Creates an instance of [MarketData]
  MarketData();

  /// Yahoo data source
  static const String yahooSource = 'https://finance.yahoo.com/';

  /// CoinGecko data source
  static const String coinGeckoSource = 'https://www.coingecko.com/';

  static const int _goldOunces = 216_265 *
      35274; // tons to ounces -  https://www.gold.org/goldhub/data/how-much-gold
  static const int _silverOunces = 1_600_000 *
      35274; // tons to ounces - https://cpmgroup.com/how-much-silver-is-above-ground/
  static const int _platinumOunces = 10_000 *
      35274; // tons to ounces - https://learn.apmex.com/answers/how-much-platinum-is-in-the-world/
  static const int _palladiumOunces = 6_000 *
      35274; // tons to ounces - https://online.kitco.com/fundamentals/palladium-investment

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

  YahooSparklineData _parseSparklineData(
    Map<String, dynamic> parsedData,
  ) {
    // ignore: avoid_dynamic_calls
    final sparkline = (parsedData['chart']['result'][0]['indicators']['quote']
            [0]['close'] as List<dynamic>)
        .map((e) => e as num?)
        .toList();
    final sparklineTimestamps =
        // ignore: avoid_dynamic_calls
        (parsedData['chart']['result'][0]['timestamp'] as List<dynamic>)
            .map((e) => e as int)
            .toList();
    return YahooSparklineData(
      sparkline: sparkline,
      sparklineTimestamps: sparklineTimestamps,
    );
  }

  Future<YahooSparklineData?> _yahooSparkline(String ticker) async {
    // Fetch the data from Yahoo Finance
    final url = 'https://query2.finance.yahoo.com/v8/finance/chart/$ticker';
    final data = await downloadFile(url, {'interval': '1h', 'range': '5d'});
    if (data == null) {
      _log.warning('Failed to download data for ticker: $ticker');
      return null;
    }
    // Parse the data into a list of AmountEntry objects
    final parsedData = jsonDecode(data) as Map<String, dynamic>;
    return _parseSparklineData(parsedData);
  }

  Future<MarketCapEntry?> _tickerMarketCap(
    String ticker,
    double supply,
    String name,
    MarketCap type,
    String serverUrl,
  ) async {
    // Fetch the data from Yahoo Finance
    final url = 'https://query2.finance.yahoo.com/v8/finance/chart/$ticker';
    final data = await downloadFile(url, {'interval': '1h', 'range': '5d'});
    if (data == null) {
      _log.warning('Failed to download data for ticker: $ticker');
      return null;
    }
    // Parse the data into a list of AmountEntry objects
    final parsedData = jsonDecode(data) as Map<String, dynamic>;
    // ignore: avoid_dynamic_calls
    final price = parsedData['chart']['result'][0]['meta']['regularMarketPrice']
        as double;
    final sparklineData = _parseSparklineData(parsedData);
    final sparkline = sparklineData.sparkline;
    final sparklineTimestamps = sparklineData.sparklineTimestamps;
    double priceChangePercent24h = 0;
    if (sparkline.length > 24 && sparkline[sparkline.length - 1 - 24] != null) {
      final price24hoursAgo = sparkline[sparkline.length - 1 - 24]!.toDouble();
      priceChangePercent24h =
          ((price - price24hoursAgo) / price24hoursAgo) * 100;
    } else {
      _log.warning('Failed to get price 24 hours ago for ticker: $ticker');
    }
    final marketCap = price * supply;
    // ignore: avoid_dynamic_calls
    final high24h = parsedData['chart']['result'][0]['meta']
        ['regularMarketDayHigh'] as double;
    // ignore: avoid_dynamic_calls
    final low24h = parsedData['chart']['result'][0]['meta']
        ['regularMarketDayLow'] as double;
    return MarketCapEntry(
      supply: supply,
      price: price,
      sparkline: sparkline,
      sparklineTimestamps: sparklineTimestamps,
      high24h: high24h,
      low24h: low24h,
      priceChangePercent24h: priceChangePercent24h,
      marketCap: marketCap,
      ticker: ticker,
      name: name,
      image: '$serverUrl/images/logos_${type.name}/${name.toLowerCase()}.svg',
      type: type,
    );
  }

  Future<List<MarketCapEntry>?> _marketCapMetals(String serverUrl) async {
    // get gold market cap from yahoo finance
    final goldMarketCap = await _tickerMarketCap(
      'GC=F',
      _goldOunces.toDouble(),
      'Gold',
      MarketCap.metals,
      serverUrl,
    );
    if (goldMarketCap == null) {
      _log.warning('Failed to download data for ticker: GC=F');
      return null;
    }
    // get silver market cap from yahoo finance
    final silverMarketCap = await _tickerMarketCap(
      'SI=F',
      _silverOunces.toDouble(),
      'Silver',
      MarketCap.metals,
      serverUrl,
    );
    if (silverMarketCap == null) {
      _log.warning('Failed to download data for ticker: SI=F');
      return null;
    }
    // get platinum market cap from yahoo finance
    final platinumMarketCap = await _tickerMarketCap(
      'PL=F',
      _platinumOunces.toDouble(),
      'Platinum',
      MarketCap.metals,
      serverUrl,
    );
    if (platinumMarketCap == null) {
      _log.warning('Failed to download data for ticker: PL=F');
      return null;
    }
    // get palladium market cap from yahoo finance
    final palladiumMarketCap = await _tickerMarketCap(
      'PA=F',
      _palladiumOunces.toDouble(),
      'Palladium',
      MarketCap.metals,
      serverUrl,
    );
    if (palladiumMarketCap == null) {
      _log.warning('Failed to download data for ticker: PA=F');
      return null;
    }
    // create the market cap entries
    return [
      goldMarketCap,
      silverMarketCap,
      platinumMarketCap,
      palladiumMarketCap,
    ];
  }

  Future<List<MarketCapEntry>?> _marketCapCrypto() async {
    // get crypto market cap from coin gecko
    const url = 'https://api.coingecko.com/api/v3/coins/markets';
    final data = await downloadFile(url, {
      'vs_currency': 'usd',
      'order': 'market_cap_desc',
      'per_page': '150',
      'page': '1',
      'sparkline': 'true',
      'price_change_percentage': '1h,24h,7d',
    });
    if (data == null) {
      _log.warning('Failed to download crypto data');
      return null;
    }
    // Parse the data into a list of MarketCapEntry objects
    final parsedData = jsonDecode(data) as List<dynamic>;
    return parsedData
        .map(
          (e) => MarketCapEntry(
            // ignore: avoid_dynamic_calls
            supply: (e['circulating_supply'] as num).toDouble(),
            // ignore: avoid_dynamic_calls
            price: (e['current_price'] as num).toDouble(),
            // ignore: avoid_dynamic_calls
            sparkline: (e['sparkline_in_7d']['price'] as List<dynamic>)
                .map((e) => e as double)
                .toList(),
            // ignore: avoid_dynamic_calls
            high24h: (e['high_24h'] as num).toDouble(),
            // ignore: avoid_dynamic_calls
            low24h: (e['low_24h'] as num).toDouble(),
            priceChangePercent24h:
                // ignore: avoid_dynamic_calls
                (e['price_change_percentage_24h'] as num).toDouble(),
            // ignore: avoid_dynamic_calls
            marketCap: (e['market_cap'] as num).toDouble(),
            // ignore: avoid_dynamic_calls
            ticker: e['symbol'] as String,
            // ignore: avoid_dynamic_calls
            name: e['name'] as String,
            // ignore: avoid_dynamic_calls
            image: e['image'] as String,
            type: MarketCap.crypto,
          ),
        )
        .toList();
  }

  double _parseTVAmount(String amountStr) {
    // Parse the market cap string into a double
    if (amountStr.endsWith('T')) {
      return double.parse(amountStr.substring(0, amountStr.length - 1)) *
          1_000_000_000_000;
    } else if (amountStr.endsWith('B')) {
      return double.parse(amountStr.substring(0, amountStr.length - 1)) *
          1_000_000_000;
    } else if (amountStr.endsWith('M')) {
      return double.parse(amountStr.substring(0, amountStr.length - 1)) *
          1_000_000;
    } else {
      return double.parse(amountStr.replaceAll(',', ''));
    }
  }

  double _parseTVPriceChange(String priceChangeStr) {
    // Parse the price change string into a double
    var sign = 1;
    var p = priceChangeStr;
    if (p.startsWith('+')) {
      p = p.substring(1);
    }
    if (p.startsWith('-') || p.startsWith('−')) {
      sign = -1;
      p = p.substring(1);
    }
    if (p.endsWith('%')) {
      p = p.substring(0, p.length - 1);
    }
    try {
      return double.parse(p) * sign;
    } catch (e) {
      _log.warning('Failed to parse price change: $p, ($priceChangeStr)');
      return 0;
    }
  }

  String? _yahooTicker(String ticker) {
    const largestCompanyYahooTickers = {
      'AAPL': 'AAPL',
      'MSFT': 'MSFT',
      'NVDA': 'NVDA',
      'AMZN': 'AMZN',
      'GOOG': 'GOOG',
      '2222': '2222.SR',
      'META': 'META',
      'BRK.A': 'BRK-A',
      'TSLA': 'TSLA',
      'AVGO': 'AVGO',
      'LLY': 'LLY',
      'WMT': 'WMT',
      '2330': '2330.TW',
      'JPM': 'JPM',
      'V': 'V',
      '700': '0700.HK',
      'MA': 'MA',
      'NFLX': 'NFLX',
      'XOM': 'XOM',
      'COST': 'COST',
      'ORCL': 'ORCL',
      'UNH': 'UNH',
      'PG': 'PG',
      'JNJ': 'JNJ',
      'HD': 'HD',
      'ABBV': 'ABBV',
      '601398': '601398.SS',
      'SAP': 'SAP',
      'KO': 'KO',
      'BAC': 'BAC',
      'BABA': 'BABA',
      'MC': 'MC.PA',
      'RMS': 'RMS.PA',
      'NOVO_B': 'NOVO-B.CO',
      'PLTR': 'PLTR',
      'TMUS': 'TMUS',
      '600519': '600519.SS',
      'PM': 'PM',
      '601288': '601288.SS',
      'NESN': 'NESN.SW',
      'ASML': 'ASML',
      'RO': 'ROG.SW',
      'CRM': 'CRM',
      '005930': '005930.KS',
      '7203': '7203.T',
      'CVX': 'CVX',
      'IHC': 'IHC.AE',
      '600941': '600941.SS',
      'MCD': 'MCD',
      'WFC': 'WFC',
      'CSCO': 'CSCO',
      'OR': 'OR.PA',
      'ABT': 'ABT',
      '601939': '601939.SS',
      'IBM': 'IBM',
      'AZN': 'AZN',
      'GE': 'GE',
      'NOVN': 'NOVN.SW',
      'LIN': 'LIN',
      '601988': '601988.SS',
      'MRK': 'MRK',
      'RELIANCE': 'RELIANCE.NS',
      'HSBA': 'HSBA.L',
      'T': 'T',
      'SHEL': 'SHEL',
      'NOW': 'NOW',
      '601857': '601857.SS',
      'MS': 'MS',
      'AXP': 'AXP',
      'ISRG': 'ISRG',
      'SIE': 'SIE.DE',
      'ACN': 'ACN',
      'PEP': 'PEP',
      'VZ': 'VZ',
      'DTE': 'DTE.DE',
      'CBA': 'CBA.AX',
      'INTU': 'INTU',
      'ITX': 'ITX.MC',
      'HDFCBANK': 'HDFCBANK.NS',
      'GS': 'GS',
      'RTX': 'RTX',
      'RY': 'RY',
      'UBER': 'UBER',
      'QCOM': 'QCOM',
      'DIS': 'DIS',
      'BX': 'BX',
      'BKNG': 'BKNG',
      'TMO': 'TMO',
      'PGR': 'PGR',
      'ADBE': 'ADBE',
      'ALV': 'ALV.DE',
      'AMD': 'AMD',
      'ULVR': 'ULVR.L',
      '002594': '002594.SZ',
      '1810': '1810.HK',
      'AMGN': 'AMGN',
      'BSX': 'BSX',
      'SPGI': 'SPGI',
      '6758': '6758.T',
      'SCHW': 'SCHW',
    };
    if (!largestCompanyYahooTickers.keys.contains(ticker)) {
      _log.warning('Ticker $ticker is not in the list of largest companies');
      return null;
    }
    return largestCompanyYahooTickers[ticker];
  }

  Future<List<MarketCapEntry>?> _marketCapStocks(serverUrl) async {
    const url =
        'https://www.tradingview.com/markets/world-stocks/worlds-largest-companies/';
    final data = await downloadFile(url, {});
    if (data == null) {
      _log.warning('Failed to download stocks data');
      return null;
    }
    // Parse the data into a list of MarketCapEntry objects
    final document = parse(data);
    final entries = <MarketCapEntry>[];
    // Find the table with the class 'table-Ngq2xrcG'
    final table = document.querySelector('.table-Ngq2xrcG');
    if (table == null) {
      _log.warning('Failed to find stocks table');
      return null;
    }
    // Find all the rows in the table
    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      // Find all the cells in the row
      final cells = row.querySelectorAll('td');
      if (cells.length < 5) {
        continue; // Skip rows with less than 5 cells
      }
      // Get the ticker symbol from the first cell
      final tickerCell = cells[0].children[0];
      if (!tickerCell.className.startsWith('tickerCell')) {
        continue; // Skip rows without a ticker cell
      }
      if (tickerCell.children.length < 3) {
        continue; // Skip rows without sufficient ticker cell children
      }
      final link = tickerCell.children[2];
      final ticker = link.text.trim();
      final sup = tickerCell.children[3];
      final name = sup.text.trim();
      // get the market cap from the third cell
      final marketCapCell = cells[2];
      marketCapCell.children[0].remove();
      final marketCapStr = marketCapCell.text.trim();
      final marketCap = _parseTVAmount(marketCapStr);
      // get price from the fourth cell
      final priceCell = cells[3];
      priceCell.children[0].remove();
      final priceStr = priceCell.text.trim();
      final price = _parseTVAmount(priceStr);
      // get the price change percent from the fifth cell
      final priceChangeStr = cells[4].text.trim();
      if (priceChangeStr == '—') {
        continue; // Skip rows strange price change
      }
      final priceChange = _parseTVPriceChange(priceChangeStr);
      // create the market cap entry
      entries.add(
        MarketCapEntry(
          supply: 0,
          price: price,
          high24h: 0,
          low24h: 0,
          priceChangePercent24h: priceChange,
          marketCap: marketCap,
          ticker: ticker,
          name: name,
          image: '$serverUrl/images/logos_stock/${ticker.toUpperCase()}.svg',
          type: MarketCap.stocks,
        ),
      );
    }
    return entries;
  }

  /// Fetches and parses the market capitalization data into a list of
  /// MarketCapEntry objects.
  Future<MarketCapSeries?> marketCapData(
    MarketCap type,
    String serverUrl,
  ) async {
    List<MarketCapEntry>? metalsData = [];
    List<MarketCapEntry>? cryptoData = [];
    List<MarketCapEntry>? stocksData = [];
    var description = '';
    var sources = <String>[];

    switch (type) {
      case MarketCap.all:
        // Fetch and parse data for all market caps
        var data = await _marketCapMetals(serverUrl);
        if (data != null) {
          metalsData = data;
        } else {
          _log.warning('Failed to download data for metals');
          return null;
        }
        data = await _marketCapCrypto();
        if (data != null) {
          cryptoData = data;
        } else {
          _log.warning('Failed to download data for crypto');
          return null;
        }
        data = await _marketCapStocks(serverUrl);
        if (data != null) {
          stocksData = data;
        } else {
          _log.warning('Failed to download data for stocks');
          return null;
        }
        description = 'All Market Caps';
        sources = [
          MarketData.yahooSource,
          MarketData.coinGeckoSource,
        ];
      case MarketCap.metals:
        // Fetch and parse data for metals
        final data = await _marketCapMetals(serverUrl);
        if (data != null) {
          metalsData = data;
        } else {
          _log.warning('Failed to download data for metals');
          return null;
        }
        description = 'Metals';
        sources = [MarketData.yahooSource];
      case MarketCap.crypto:
        // Fetch and parse data for crypto
        final data = await _marketCapCrypto();
        if (data != null) {
          cryptoData = data;
        } else {
          _log.warning('Failed to download data for crypto');
          return null;
        }
        description = 'Crypto';
        sources = [MarketData.coinGeckoSource];
      case MarketCap.stocks:
        // Fetch and parse data for stocks
        final data = await _marketCapStocks(serverUrl);
        if (data != null) {
          stocksData = data;
        } else {
          _log.warning('Failed to download data for stocks');
          return null;
        }
        description = 'Stocks';
        sources = ['TODO'];
    }
    // Combine all data into a single list
    // and sort the data by market cap in descending order
    final allData = <MarketCapEntry>[
      ...metalsData,
      ...cryptoData,
      ...stocksData,
    ]..sort((a, b) => b.marketCap.compareTo(a.marketCap));
    // Create the market cap series
    return MarketCapSeries(
      description: description,
      sources: sources,
      data: allData,
    );
  }

  /// Fetches and parses the sparkline data for a given ticker symbol.
  Future<YahooSparklineData?> sparkline(String ticker) async {
    // Fetch the data from Yahoo Finance
    final data = await _yahooSparkline(_yahooTicker(ticker) ?? ticker);
    if (data == null) {
      _log.warning('Failed to download data for ticker: $ticker');
      return null;
    }
    return data;
  }
}
