import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

/// Represents a single entry in the M2 data.
@JsonSerializable()
class M2Entry extends Equatable {
  final DateTime date;
  final double amount;

  const M2Entry({required this.date, required this.amount});

  /// Creates an instance of [M2Entry] from a JSON map.
  factory M2Entry.fromJson(Map<String, dynamic> json) =>
      _$M2EntryFromJson(json);

  /// Converts the instance of [M2Entry] to a JSON map.
  Map<String, dynamic> toJson() => _$M2EntryToJson(this);

  @override
  List<Object?> get props => [date, amount];

  @override
  String toString() => 'M2Entry(date: $date, amount: $amount)';
}
