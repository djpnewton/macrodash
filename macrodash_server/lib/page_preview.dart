import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import 'cache.dart';
import 'market_data.dart';
import 'sov_data.dart';

/// Builds the preview card for [page], or null when the data is unavailable.
///
/// Results are cached so the HTML page and its image share one data fetch.
Future<PreviewData?> buildPagePreview({
  required String page,
  required Map<String, String> params,
  required MarketData marketData,
  required SovData sovData,
  required Cache cache,
  required String serverUrl,
}) async {
  final key = 'page-preview:${page.toLowerCase()}:${_cacheQuery(params)}';
  final cached = cache.get(key);
  if (cached is PreviewData) {
    return cached;
  }

  final preview = await _buildPagePreview(
    page: page,
    params: params,
    marketData: marketData,
    sovData: sovData,
    serverUrl: serverUrl,
  );
  if (preview != null) {
    cache.add(
      key,
      preview,
      expirationDuration: const Duration(minutes: 15),
    );
  }
  return preview;
}

Future<PreviewData?> _buildPagePreview({
  required String page,
  required Map<String, String> params,
  required MarketData marketData,
  required SovData sovData,
  required String serverUrl,
}) async {
  switch (page.toLowerCase()) {
    case 'm2':
      final region =
          _enumByName(M2Region.values, params['region']) ?? M2Region.all;
      final series = await sovData.m2Series(region);
      if (series == null) {
        return null;
      }
      return PreviewData.fromSeries(
        title: 'M2 Money Supply',
        subtitle: '${m2RegionLabels[region]} - Trillions of Dollars',
        data: series.data,
        unit: 'T USD',
        range: _range(params),
      );

    case 'debt':
      final region =
          _enumByName(DebtRegion.values, params['region']) ?? DebtRegion.all;
      final series = await sovData.debtSeries(region);
      if (series == null) {
        return null;
      }
      return PreviewData.fromSeries(
        title: 'Public Debt',
        subtitle: '${debtRegionLabels[region]} - Trillions of Dollars',
        data: series.data,
        unit: 'T USD',
        range: _range(params),
      );

    case 'bondrates':
      final region = _enumByName(BondRateRegion.values, params['region']) ??
          BondRateRegion.usa;
      final term = _enumByName(BondTerm.values, params['category']) ??
          BondTerm.thirtyYear;
      final series = await sovData.bondRateSeries(region, term);
      if (series == null) {
        return null;
      }
      return PreviewData.fromSeries(
        title: 'Bond Rates',
        subtitle: '${bondRateRegionLabels[region]} - ${_bondTermLabels[term]}',
        data: series.data,
        unit: '%',
        range: _range(params),
        changeMode: PreviewChangeMode.points,
      );

    case 'indices':
      final region = _enumByName(MarketIndexRegion.values, params['region']) ??
          MarketIndexRegion.usa;
      final index = switch (region) {
        MarketIndexRegion.usa =>
          _enumByName(MarketIndexUsa.values, params['category']) ??
              MarketIndexUsa.sp500,
        MarketIndexRegion.europe =>
          _enumByName(MarketIndexEurope.values, params['category']) ??
              MarketIndexEurope.ftse100,
        MarketIndexRegion.asia =>
          _enumByName(MarketIndexAsia.values, params['category']) ??
              MarketIndexAsia.nikkei225,
      };
      final data = await marketData.indexData(index, _range(params));
      if (data == null) {
        return null;
      }
      return PreviewData.fromSeries(
        title: _indexLabel(index),
        subtitle: 'Index - ${marketIndexRegionLabels[region]}',
        data: data.priceData,
        unit: 'pts',
      );

    case 'futures':
      final future =
          _enumByName(Futures.values, params['region']) ?? Futures.gold;
      final data = await marketData.futureData(future, _range(params));
      if (data == null) {
        return null;
      }
      return PreviewData.fromSeries(
        title: futuresLabels[future]!,
        subtitle: 'Futures',
        data: data.priceData,
        unit: data.currency,
      );

    case 'marketcap':
      final type = _enumByName(MarketCategory.values, params['market']) ??
          MarketCategory.all;
      final result = await marketData.marketCapData(type, serverUrl);
      if (result == null) {
        return null;
      }
      return PreviewData.fromMarketCap(
        title: 'Market Caps',
        subtitle: marketCategoryLabels[type]!,
        entries: result.data,
      );

    default:
      return null;
  }
}

const _bondTermLabels = {
  BondTerm.thirtyYear: '30-Year Treasury',
  BondTerm.twentyYear: '20-Year Treasury',
  BondTerm.tenYear: '10-Year Treasury',
  BondTerm.fiveYear: '5-Year Treasury',
  BondTerm.oneYear: '1-Year Treasury',
};

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  final normalized = name?.toLowerCase();
  for (final value in values) {
    if (value.name.toLowerCase() == normalized) {
      return value;
    }
  }
  return null;
}

DataRange _range(Map<String, String> params) {
  final range =
      _enumByName(DataRange.values, params['range'] ?? params['zoom']) ??
          DataRange.max;
  return range;
}

String _indexLabel(Enum index) => switch (index) {
      final MarketIndexUsa value => marketIndexUsaLabels[value]!,
      final MarketIndexEurope value => marketIndexEuropeLabels[value]!,
      final MarketIndexAsia value => marketIndexAsiaLabels[value]!,
      _ => index.name,
    };

String _cacheQuery(Map<String, String> params) {
  final entries = params.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key}=${e.value}').join('&');
}
