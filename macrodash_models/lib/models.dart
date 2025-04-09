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

/// Enum to represent the region for Debt data.
enum DebtRegion { usa, all }

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

/// Represents a single entry in price/amount series.
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
