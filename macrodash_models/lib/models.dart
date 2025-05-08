import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

/// Represents the server version and minimum client version
@JsonSerializable()
class VersionInfo extends Equatable {
  final int version;
  final int minClientVersion;

  const VersionInfo({required this.version, required this.minClientVersion});

  /// Creates an instance of [VersionInfo] from a JSON map.
  factory VersionInfo.fromJson(Map<String, dynamic> json) =>
      _$VersionInfoFromJson(json);

  /// Converts the instance of [VersionInfo] to a JSON map.
  Map<String, dynamic> toJson() => _$VersionInfoToJson(this);

  @override
  List<Object?> get props => [version, minClientVersion];

  @override
  String toString() =>
      'VersionInfo(version: $version, minClientVersion: $minClientVersion)';
}

/// Enum to represent the range of data.
enum DataRange {
  oneDay,
  fiveDays,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  twoYears,
  fiveYears,
  tenYears,
  max,
}

/// Enum to represent the region for M2 data.
enum M2Region { usa, euro, japan, all }

final m2RegionLabels = {
  M2Region.usa: 'USA',
  M2Region.euro: 'Euro',
  M2Region.japan: 'Japan',
  M2Region.all: 'All',
};

/// Enum to represent the region for Debt data.
enum DebtRegion { usa, all }

final debtRegionLabels = {DebtRegion.usa: 'USA', DebtRegion.all: 'All'};

/// Enum to represent the region for Bond Rate data.
enum BondRateRegion { usa }

final bondRateRegionLabels = {BondRateRegion.usa: 'USA'};

/// Enum to represent the term of bond.
enum BondTerm { thirtyYear, twentyYear, tenYear, fiveYear, oneYear }

final bondTermLabels = {
  BondTerm.thirtyYear: '30Y',
  BondTerm.twentyYear: '20Y',
  BondTerm.tenYear: '10Y',
  BondTerm.fiveYear: '5Y',
  BondTerm.oneYear: '1Y',
};

/// Enum to represent the market index region.
enum MarketIndexRegion { usa, europe, asia }

final marketIndexRegionLabels = {
  MarketIndexRegion.usa: 'USA',
  MarketIndexRegion.europe: 'Europe',
  MarketIndexRegion.asia: 'Asia',
};

/// Enum to represent the market index
enum MarketIndexUsa { sp500, nasdaq, dowjones, russell2000, vix, dxy }

final marketIndexUsaLabels = {
  MarketIndexUsa.sp500: 'S&P 500',
  MarketIndexUsa.nasdaq: 'NASDAQ',
  MarketIndexUsa.dowjones: 'Dow Jones',
  MarketIndexUsa.russell2000: 'Russell 2000',
  MarketIndexUsa.vix: 'VIX',
  MarketIndexUsa.dxy: 'DXY',
};

enum MarketIndexEurope { ftse100, dax, cac40, ibex35, euroStocks50 }

final marketIndexEuropeLabels = {
  MarketIndexEurope.ftse100: 'FTSE 100',
  MarketIndexEurope.dax: 'DAX',
  MarketIndexEurope.cac40: 'CAC 40',
  MarketIndexEurope.ibex35: 'IBEX 35',
  MarketIndexEurope.euroStocks50: 'Stoxx 50',
};

enum MarketIndexAsia { nikkei225, hangSeng, sse, sensex, nifty50 }

final marketIndexAsiaLabels = {
  MarketIndexAsia.nikkei225: 'Nikkei 225',
  MarketIndexAsia.hangSeng: 'HSI',
  MarketIndexAsia.sse: 'SSE',
  MarketIndexAsia.sensex: 'SENSEX',
  MarketIndexAsia.nifty50: 'Nifty 50',
};

enum Futures { gold, silver, crudeOil, brentCrude, naturalGas, copper }

final futuresLabels = {
  Futures.gold: 'Gold',
  Futures.silver: 'Silver',
  Futures.crudeOil: 'Crude Oil',
  Futures.brentCrude: 'Brent Crude',
  Futures.naturalGas: 'Natural Gas',
  Futures.copper: 'Copper',
};

enum MarketCategory { metals, crypto, stocks, all }

final marketCategoryLabels = {
  MarketCategory.metals: 'Metals',
  MarketCategory.crypto: 'Crypto',
  MarketCategory.stocks: 'Stocks',
  MarketCategory.all: 'All',
};

/// Represents a single entry in price/amount series.
@JsonSerializable()
class AmountEntry extends Equatable {
  final DateTime date;
  final double amount;

  const AmountEntry({required this.date, required this.amount});

  /// Creates an instance of [AmountEntry] from a JSON map.
  factory AmountEntry.fromJson(Map<String, dynamic> json) =>
      _$AmountEntryFromJson(json);

  /// Converts the instance of [AmountEntry] to a JSON map.
  Map<String, dynamic> toJson() => _$AmountEntryToJson(this);

  @override
  List<Object?> get props => [date, amount];

  @override
  String toString() => 'AmountEntry(date: $date, amount: $amount)';
}

/// Represents a price/amount series.
@JsonSerializable()
class AmountSeries extends Equatable {
  final String description;
  final List<String> sources;
  final List<AmountEntry> data;

  const AmountSeries({
    required this.description,
    required this.sources,
    required this.data,
  });

  /// Creates an instance of [AmountSeries] from a JSON map.
  factory AmountSeries.fromJson(Map<String, dynamic> json) =>
      _$AmountSeriesFromJson(json);

  /// Converts the instance of [AmountSeries] to a JSON map.
  Map<String, dynamic> toJson() => _$AmountSeriesToJson(this);

  @override
  List<Object?> get props => [description, sources, data];

  @override
  String toString() =>
      'AmountSeries(description: $description, sources: $sources, data: $data)';
}

@JsonSerializable()
class MarketOverviewEntry extends Equatable {
  final double supply;
  final double price;
  final List<num?>? sparkline;
  final List<int>? sparklineTimestamps;
  final double high24h;
  final double low24h;
  final double priceChangePercent24h;
  final double marketCap;
  final String ticker;
  final String name;
  final String? image;
  final MarketCategory type;
  final String? moreInfoLink;

  const MarketOverviewEntry({
    required this.supply,
    required this.price,
    this.sparkline,
    this.sparklineTimestamps,
    required this.high24h,
    required this.low24h,
    required this.priceChangePercent24h,
    required this.marketCap,
    required this.ticker,
    required this.name,
    required this.image,
    required this.type,
    required this.moreInfoLink,
  });

  /// Creates an instance of [MarketOverviewEntry] from a JSON map.
  factory MarketOverviewEntry.fromJson(Map<String, dynamic> json) =>
      _$MarketOverviewEntryFromJson(json);

  /// Converts the instance of [MarketOverviewEntry] to a JSON map.
  Map<String, dynamic> toJson() => _$MarketOverviewEntryToJson(this);

  @override
  List<Object?> get props => [
    supply,
    price,
    sparkline,
    sparklineTimestamps,
    high24h,
    low24h,
    priceChangePercent24h,
    marketCap,
    ticker,
    name,
    image,
    type,
    moreInfoLink,
  ];

  @override
  String toString() =>
      'MarketOverviewEntry(supply: $supply, price: $price, marketCap: $marketCap, ticker: $ticker, name: $name, type: $type)';
}

@JsonSerializable()
class MarketCapSeries extends Equatable {
  final String description;
  final List<String> sources;
  final List<MarketOverviewEntry> data;

  const MarketCapSeries({
    required this.description,
    required this.sources,
    required this.data,
  });

  /// Creates an instance of [MarketCapSeries] from a JSON map.
  factory MarketCapSeries.fromJson(Map<String, dynamic> json) =>
      _$MarketCapSeriesFromJson(json);

  /// Converts the instance of [MarketCapSeries] to a JSON map.
  Map<String, dynamic> toJson() => _$MarketCapSeriesToJson(this);

  @override
  List<Object?> get props => [description, sources, data];

  @override
  String toString() =>
      'MarketCapSeries(description: $description, sources: $sources, data: $data)';
}

@JsonSerializable()
class YahooSparklineData extends Equatable {
  final List<num?> sparkline;
  final List<int> sparklineTimestamps;

  YahooSparklineData({
    required this.sparkline,
    required this.sparklineTimestamps,
  });

  /// Creates an instance of [YahooSparklineData] from a JSON map.
  factory YahooSparklineData.fromJson(Map<String, dynamic> json) =>
      _$YahooSparklineDataFromJson(json);

  /// Converts the instance of [YahooSparklineData] to a JSON map.
  Map<String, dynamic> toJson() => _$YahooSparklineDataToJson(this);

  @override
  List<Object?> get props => [sparkline, sparklineTimestamps];

  @override
  String toString() =>
      'YahooSparklineData(sparkline: $sparkline, sparklineTimestamps: $sparklineTimestamps)';
}

@JsonSerializable()
class TickerSearchEntry extends Equatable {
  final String ticker;
  final String name;
  final String exchange;

  const TickerSearchEntry({
    required this.ticker,
    required this.name,
    required this.exchange,
  });

  /// Creates an instance of [TickerSearchEntry] from a JSON map.
  factory TickerSearchEntry.fromJson(Map<String, dynamic> json) =>
      _$TickerSearchEntryFromJson(json);

  /// Converts the instance of [TickerSearchEntry] to a JSON map.
  Map<String, dynamic> toJson() => _$TickerSearchEntryToJson(this);

  @override
  List<Object?> get props => [ticker, name, exchange];

  @override
  String toString() =>
      'TickerSearchEntry(ticker: $ticker, name: $name, exchange: $exchange)';
}

@JsonSerializable()
class TickerSearchResult extends Equatable {
  final List<TickerSearchEntry> data;

  const TickerSearchResult({required this.data});

  /// Creates an instance of [TickerSearchResult] from a JSON map.
  factory TickerSearchResult.fromJson(Map<String, dynamic> json) =>
      _$TickerSearchResultFromJson(json);

  /// Converts the instance of [TickerSearchResult] to a JSON map.
  Map<String, dynamic> toJson() => _$TickerSearchResultToJson(this);

  @override
  List<Object?> get props => [data];

  @override
  String toString() => 'TickerSearchResult(data: $data)';
}

@JsonSerializable()
class CustomTickerResult extends Equatable {
  final String ticker1;
  final String? ticker2;
  final String shortName;
  final String longName;
  final List<String> sources;
  final List<AmountEntry> data;
  final String currency;

  const CustomTickerResult({
    required this.ticker1,
    required this.ticker2,
    required this.shortName,
    required this.longName,
    required this.sources,
    required this.data,
    required this.currency,
  });

  /// Creates an instance of [CustomTickerResult] from a JSON map.
  factory CustomTickerResult.fromJson(Map<String, dynamic> json) =>
      _$CustomTickerResultFromJson(json);

  /// Converts the instance of [CustomTickerResult] to a JSON map.
  Map<String, dynamic> toJson() => _$CustomTickerResultToJson(this);

  @override
  List<Object?> get props => [
    ticker1,
    ticker2,
    shortName,
    longName,
    sources,
    data,
    currency,
  ];

  @override
  String toString() =>
      'CustomTickerResult(ticker1: $ticker1, ticker2: $ticker2, short name: $shortName, sources: $sources, data: $data)';
}

@JsonSerializable()
class DashTicker extends Equatable {
  final String ticker1;
  final String? ticker2;

  const DashTicker({required this.ticker1, required this.ticker2});

  /// Creates an instance of [DashTicker] from a JSON map.
  factory DashTicker.fromJson(Map<String, dynamic> json) =>
      _$DashTickerFromJson(json);

  /// Converts the instance of [DashTicker] to a JSON map.
  Map<String, dynamic> toJson() => _$DashTickerToJson(this);

  @override
  List<Object?> get props => [ticker1, ticker2];
}

@JsonSerializable()
class DashTickers extends Equatable {
  final List<DashTicker> tickers;

  const DashTickers({required this.tickers});

  /// Creates an instance of [DashTickers] from a JSON map.
  factory DashTickers.fromJson(Map<String, dynamic> json) =>
      _$DashTickersFromJson(json);

  /// Converts the instance of [DashTickers] to a JSON map.
  Map<String, dynamic> toJson() => _$DashTickersToJson(this);

  @override
  List<Object?> get props => [tickers];
}
