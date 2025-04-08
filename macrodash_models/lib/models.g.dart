// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VersionInfo _$VersionInfoFromJson(Map<String, dynamic> json) => VersionInfo(
  version: (json['version'] as num).toInt(),
  minClientVersion: (json['minClientVersion'] as num).toInt(),
);

Map<String, dynamic> _$VersionInfoToJson(VersionInfo instance) =>
    <String, dynamic>{
      'version': instance.version,
      'minClientVersion': instance.minClientVersion,
    };

AmountEntry _$AmountEntryFromJson(Map<String, dynamic> json) => AmountEntry(
  date: DateTime.parse(json['date'] as String),
  amount: (json['amount'] as num).toDouble(),
);

Map<String, dynamic> _$AmountEntryToJson(AmountEntry instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'amount': instance.amount,
    };

AmountSeries _$AmountSeriesFromJson(Map<String, dynamic> json) => AmountSeries(
  description: json['description'] as String,
  sources: (json['sources'] as List<dynamic>).map((e) => e as String).toList(),
  data:
      (json['data'] as List<dynamic>)
          .map((e) => AmountEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$AmountSeriesToJson(AmountSeries instance) =>
    <String, dynamic>{
      'description': instance.description,
      'sources': instance.sources,
      'data': instance.data,
    };
