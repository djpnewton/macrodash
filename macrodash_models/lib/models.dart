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
enum BondTerm { thirtyYear, twentyYear }

final bondTermLabels = {BondTerm.thirtyYear: '30Y', BondTerm.twentyYear: '20Y'};

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
