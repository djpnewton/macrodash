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

enum MarketCap { metals, crypto, stocks, all }

final marketCapLabels = {
  MarketCap.metals: 'Metals',
  MarketCap.crypto: 'Crypto',
  MarketCap.stocks: 'Stocks',
  MarketCap.all: 'All',
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
class MarketCapEntry extends Equatable {
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
  final MarketCap type;
  final String? moreInfoLink;

  const MarketCapEntry({
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

  /// Creates an instance of [MarketCapEntry] from a JSON map.
  factory MarketCapEntry.fromJson(Map<String, dynamic> json) =>
      _$MarketCapEntryFromJson(json);

  /// Converts the instance of [MarketCapEntry] to a JSON map.
  Map<String, dynamic> toJson() => _$MarketCapEntryToJson(this);

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
      'MarketCapEntry(supply: $supply, price: $price, marketCap: $marketCap, ticker: $ticker, name: $name, type: $type)';
}

@JsonSerializable()
class MarketCapSeries extends Equatable {
  final String description;
  final List<String> sources;
  final List<MarketCapEntry> data;

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
