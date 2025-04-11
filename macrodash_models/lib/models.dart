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
