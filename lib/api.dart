import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:macrodash_models/models.dart';

import 'config.dart';
import 'result.dart';

class ServerApi {
  final Logger log = Logger('api');

  /// Downloads a file from the given [url] and returns its content as a [String].
  Future<Result<String>> downloadFile(
    String url,
    Map<String, dynamic>? queryParameters,
  ) async {
    var uri = Uri.parse(url);
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    log.info('Downloading file from $uri');
    try {
      // Fetch the file from the URL
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        log.info('File downloaded successfully from $url');
        return Result.ok(response.body); // Return the file content as a String
      } else {
        log.severe(
          'Failed to download file. Status code: ${response.statusCode}',
        );
        return Result.error(Exception('Status code: ${response.statusCode}'));
      }
    } catch (e) {
      log.severe('Error downloading file: $e');
      return Result.error(Exception(e));
    }
  }

  /// Fetch server version information.
  Future<Result<VersionInfo>> serverVersion() async {
    const url = '$macrodashServerUrl/version';
    final result = await downloadFile(url, null);
    switch (result) {
      case Ok():
        log.info('Version data downloaded successfully from $url');
        final versionJson = jsonDecode(result.value);
        if (versionJson == null) {
          log.severe('Failed to parse version data from $url');
          return Result.error(Exception('Failed to parse version data'));
        }
        final versionInfo = VersionInfo.fromJson(versionJson);
        log.info('Version data downloaded successfully from $url');
        return Result.ok(versionInfo);
      case Error():
        log.severe('Failed to download version data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Fetches and parses the M2 data into an AmountSeries object.
  Future<Result<AmountSeries>> m2Data(M2Region region) async {
    const url = '$macrodashServerUrl/sov/m2';
    final queryParameters = {'region': region.name};
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('M2 data downloaded successfully from $url');
        final m2json = jsonDecode(result.value);
        if (m2json == null) {
          log.severe('Failed to parse M2 data from $url');
          return Result.error(Exception('Failed to parse M2 data'));
        }
        return Result.ok(AmountSeries.fromJson(m2json));
      case Error():
        log.severe('Failed to download M2 data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Fetches and parses the debt data into an AmountSeries object.
  Future<Result<AmountSeries>> debtData(DebtRegion region) async {
    const url = '$macrodashServerUrl/sov/debt';
    final queryParameters = {'region': region.name};
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('Debt data downloaded successfully from $url');
        final debtJson = jsonDecode(result.value);
        if (debtJson == null) {
          log.severe('Failed to parse debt data from $url');
          return Result.error(Exception('Failed to parse debt data'));
        }
        return Result.ok(AmountSeries.fromJson(debtJson));
      case Error():
        log.severe('Failed to download debt data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Fetches and parses the bond rate data into an AmountSeries object.
  Future<Result<AmountSeries>> bondRateData(
    BondRateRegion region,
    BondTerm term,
  ) async {
    const url = '$macrodashServerUrl/sov/bond_rates';
    final queryParameters = {'region': region.name, 'term': term.name};
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('Bond rate data downloaded successfully from $url');
        final bondRateJson = jsonDecode(result.value);
        if (bondRateJson == null) {
          log.severe('Failed to parse bond rate data from $url');
          return Result.error(Exception('Failed to parse bond rate data'));
        }
        return Result.ok(AmountSeries.fromJson(bondRateJson));
      case Error():
        log.severe('Failed to download bond rate data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Fetches and parses the market index data into an AmountSeries object.
  Future<Result<AmountSeries>> marketIndexData(
    MarketIndexRegion region,
    Enum index,
    DataRange range,
  ) async {
    const url = '$macrodashServerUrl/market/idx';
    final queryParameters = {
      'region': region.name,
      'index': index.name,
      'range': range.name,
    };
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('Market index data downloaded successfully from $url');
        final marketIndexJson = jsonDecode(result.value);
        if (marketIndexJson == null) {
          log.severe('Failed to parse market index data from $url');
          return Result.error(Exception('Failed to parse market index data'));
        }
        return Result.ok(AmountSeries.fromJson(marketIndexJson));
      case Error():
        log.severe('Failed to download market index data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Fetches and parses the futures data into an AmountSeries object.
  Future<Result<AmountSeries>> futuresData(
    Futures future,
    DataRange range,
  ) async {
    const url = '$macrodashServerUrl/market/futures';
    final queryParameters = {'future': future.name, 'range': range.name};
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('Futures data downloaded successfully from $url');
        final futuresJson = jsonDecode(result.value);
        if (futuresJson == null) {
          log.severe('Failed to parse futures data from $url');
          return Result.error(Exception('Failed to parse futures data'));
        }
        return Result.ok(AmountSeries.fromJson(futuresJson));
      case Error():
        log.severe('Failed to download futures data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Generic function to fetch AmountSeries based on the enum type.
  Future<Result<AmountSeries>> fetchAmountSeries<
    T extends Enum,
    C extends Enum
  >(T region, C? category, DataRange range) async {
    if (region is M2Region) {
      return await m2Data(region);
    } else if (region is DebtRegion) {
      return await debtData(region);
    } else if (region is BondRateRegion) {
      if (category == null) {
        log.severe('Category is required for BondRateRegion');
        return Result.error(
          Exception('Category is required for BondRateRegion'),
        );
      }
      if (category is! BondTerm) {
        log.severe('Category must be of type BondTerm');
        return Result.error(Exception('Category must be of type BondTerm'));
      }
      return await bondRateData(region, category);
    } else if (region is MarketIndexRegion) {
      if (category == null) {
        log.severe('Category is required for MarketIndexRegion');
        return Result.error(
          Exception('Category is required for MarketIndexRegion'),
        );
      }
      return await marketIndexData(region, category, range);
    } else if (region is Futures) {
      return await futuresData(region, range);
    } else {
      log.severe('Unsupported region type: ${region.runtimeType}');
      return Result.error(
        Exception('Unsupported region type: ${region.runtimeType}'),
      );
    }
  }

  /// Fetches and parses the market cap data into a MarketCapSeries object.
  Future<Result<MarketCapSeries>> fetchMarketCapSeries(
    MarketCategory type,
  ) async {
    const url = '$macrodashServerUrl/market/cap';
    final queryParameters = {'type': type.name};
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('Market cap data downloaded successfully from $url');
        final marketCapJson = jsonDecode(result.value);
        if (marketCapJson == null) {
          log.severe('Failed to parse market cap data from $url');
          return Result.error(Exception('Failed to parse market cap data'));
        }
        return Result.ok(MarketCapSeries.fromJson(marketCapJson));
      case Error():
        log.severe('Failed to download market cap data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Fetches and parses a sparkline into a YahooSparklineData object.
  Future<Result<YahooSparklineData>> fetchYahooSparkline(String ticker) async {
    const url = '$macrodashServerUrl/market/sparkline';
    final queryParameters = {'ticker': ticker};
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('Yahoo sparkline data downloaded successfully from $url');
        final sparklineJson = jsonDecode(result.value);
        if (sparklineJson == null) {
          log.severe('Failed to parse Yahoo sparkline data from $url');
          return Result.error(
            Exception('Failed to parse Yahoo sparkline data'),
          );
        }
        return Result.ok(YahooSparklineData.fromJson(sparklineJson));
      case Error():
        log.severe('Failed to download Yahoo sparkline data from $url');
        return Result.error(Exception(result.error));
    }
  }

  /// Fetches and parses a custom ticker into a CustomTickerResult object.
  Future<Result<CustomTickerResult>> fetchCustomTicker(
    DashTicker dashTicker,
    DataRange range,
  ) async {
    const url = '$macrodashServerUrl/market/custom';
    final queryParameters = {
      'ticker1': dashTicker.ticker1,
      'ticker2': dashTicker.ticker2,
      'range': range.name,
    };
    final result = await downloadFile(url, queryParameters);
    switch (result) {
      case Ok():
        log.info('Custom ticker data downloaded successfully from $url');
        final customTickerJson = jsonDecode(result.value);
        if (customTickerJson == null) {
          log.severe('Failed to parse custom ticker data from $url');
          return Result.error(Exception('Failed to parse custom ticker data'));
        }
        return Result.ok(CustomTickerResult.fromJson(customTickerJson));
      case Error():
        log.severe('Failed to download custom ticker data from $url');
        return Result.error(Exception(result.error));
    }
  }
}
