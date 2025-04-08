// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

M2Entry _$M2EntryFromJson(Map<String, dynamic> json) => M2Entry(
  date: DateTime.parse(json['date'] as String),
  amount: (json['amount'] as num).toDouble(),
);

Map<String, dynamic> _$M2EntryToJson(M2Entry instance) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'amount': instance.amount,
};
