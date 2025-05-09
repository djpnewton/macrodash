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

MarketOverviewEntry _$MarketOverviewEntryFromJson(Map<String, dynamic> json) =>
    MarketOverviewEntry(
      supply: (json['supply'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      sparkline:
          (json['sparkline'] as List<dynamic>?)?.map((e) => e as num?).toList(),
      sparklineTimestamps:
          (json['sparklineTimestamps'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList(),
      high24h: (json['high24h'] as num).toDouble(),
      low24h: (json['low24h'] as num).toDouble(),
      priceChangePercent24h: (json['priceChangePercent24h'] as num).toDouble(),
      marketCap: (json['marketCap'] as num).toDouble(),
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
      type: $enumDecode(_$MarketCategoryEnumMap, json['type']),
      moreInfoLink: json['moreInfoLink'] as String?,
    );

Map<String, dynamic> _$MarketOverviewEntryToJson(
  MarketOverviewEntry instance,
) => <String, dynamic>{
  'supply': instance.supply,
  'price': instance.price,
  'sparkline': instance.sparkline,
  'sparklineTimestamps': instance.sparklineTimestamps,
  'high24h': instance.high24h,
  'low24h': instance.low24h,
  'priceChangePercent24h': instance.priceChangePercent24h,
  'marketCap': instance.marketCap,
  'ticker': instance.ticker,
  'name': instance.name,
  'image': instance.image,
  'type': _$MarketCategoryEnumMap[instance.type]!,
  'moreInfoLink': instance.moreInfoLink,
};

const _$MarketCategoryEnumMap = {
  MarketCategory.metals: 'metals',
  MarketCategory.crypto: 'crypto',
  MarketCategory.stocks: 'stocks',
  MarketCategory.all: 'all',
};

MarketCapSeries _$MarketCapSeriesFromJson(
  Map<String, dynamic> json,
) => MarketCapSeries(
  description: json['description'] as String,
  sources: (json['sources'] as List<dynamic>).map((e) => e as String).toList(),
  data:
      (json['data'] as List<dynamic>)
          .map((e) => MarketOverviewEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$MarketCapSeriesToJson(MarketCapSeries instance) =>
    <String, dynamic>{
      'description': instance.description,
      'sources': instance.sources,
      'data': instance.data,
    };

YahooSparklineData _$YahooSparklineDataFromJson(Map<String, dynamic> json) =>
    YahooSparklineData(
      sparkline:
          (json['sparkline'] as List<dynamic>).map((e) => e as num?).toList(),
      sparklineTimestamps:
          (json['sparklineTimestamps'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
    );

Map<String, dynamic> _$YahooSparklineDataToJson(YahooSparklineData instance) =>
    <String, dynamic>{
      'sparkline': instance.sparkline,
      'sparklineTimestamps': instance.sparklineTimestamps,
    };

TickerSearchEntry _$TickerSearchEntryFromJson(Map<String, dynamic> json) =>
    TickerSearchEntry(
      ticker: json['ticker'] as String,
      name: json['name'] as String,
      exchange: json['exchange'] as String,
    );

Map<String, dynamic> _$TickerSearchEntryToJson(TickerSearchEntry instance) =>
    <String, dynamic>{
      'ticker': instance.ticker,
      'name': instance.name,
      'exchange': instance.exchange,
    };

TickerSearchResult _$TickerSearchResultFromJson(Map<String, dynamic> json) =>
    TickerSearchResult(
      data:
          (json['data'] as List<dynamic>)
              .map((e) => TickerSearchEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
    );

Map<String, dynamic> _$TickerSearchResultToJson(TickerSearchResult instance) =>
    <String, dynamic>{'data': instance.data};

CustomTickerResult _$CustomTickerResultFromJson(Map<String, dynamic> json) =>
    CustomTickerResult(
      ticker1: json['ticker1'] as String,
      ticker2: json['ticker2'] as String?,
      shortName: json['shortName'] as String,
      longName: json['longName'] as String,
      sources:
          (json['sources'] as List<dynamic>).map((e) => e as String).toList(),
      data:
          (json['data'] as List<dynamic>)
              .map((e) => AmountEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
      currency: json['currency'] as String,
    );

Map<String, dynamic> _$CustomTickerResultToJson(CustomTickerResult instance) =>
    <String, dynamic>{
      'ticker1': instance.ticker1,
      'ticker2': instance.ticker2,
      'shortName': instance.shortName,
      'longName': instance.longName,
      'sources': instance.sources,
      'data': instance.data,
      'currency': instance.currency,
    };

DashTicker _$DashTickerFromJson(Map<String, dynamic> json) => DashTicker(
  ticker1: json['ticker1'] as String,
  ticker2: json['ticker2'] as String?,
);

Map<String, dynamic> _$DashTickerToJson(DashTicker instance) =>
    <String, dynamic>{'ticker1': instance.ticker1, 'ticker2': instance.ticker2};

DashTickers _$DashTickersFromJson(Map<String, dynamic> json) => DashTickers(
  tickers:
      (json['tickers'] as List<dynamic>)
          .map((e) => DashTicker.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$DashTickersToJson(DashTickers instance) =>
    <String, dynamic>{'tickers': instance.tickers};
