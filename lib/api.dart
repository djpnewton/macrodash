import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:macrodash_models/models.dart';

import 'config.dart';

class ServerApi {
  final Logger log = Logger('api');

  /// Downloads a file from the given [url] and returns its content as a [String].
  Future<String?> downloadFile(
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
        return response.body; // Return the file content as a String
      } else {
        log.severe(
          'Failed to download file. Status code: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      log.severe('Error downloading file: $e');
      return null;
    }
  }

  /// Fetch server version information.
  Future<VersionInfo?> serverVersion() async {
    const url = '$macrodashServerUrl/version';
    final versionData = await downloadFile(url, null);
    if (versionData == null) {
      log.severe('Failed to download version data from $url');
      return null;
    }
    final versionJson = jsonDecode(versionData);
    if (versionJson == null) {
      log.severe('Failed to parse version data from $url');
      return null;
    }
    final versionInfo = VersionInfo.fromJson(versionJson);
    log.info('Version data downloaded successfully from $url');
    return versionInfo;
  }

  /// Fetches and parses the M2 data into an AmountSeries object.
  Future<AmountSeries?> m2Data(M2Region region) async {
    const url = '$macrodashServerUrl/sov/m2';

    final queryParameters = {'region': region.name};
    final m2data = await downloadFile(url, queryParameters);
    if (m2data == null) {
      log.severe('Failed to download M2 data from $url');
      return null;
    }
    final m2json = jsonDecode(m2data);
    if (m2json == null) {
      log.severe('Failed to parse M2 data from $url');
      return null;
    }
    final m2 = AmountSeries.fromJson(m2json);
    log.info('M2 data downloaded successfully from $url');
    return m2;
  }

  /// Fetches and parses the debt data into an AmountSeries object.
  Future<AmountSeries?> debtData(DebtRegion region) async {
    const url = '$macrodashServerUrl/sov/debt';

    final queryParameters = {'region': region.name};
    final debtData = await downloadFile(url, queryParameters);
    if (debtData == null) {
      log.severe('Failed to download debt data from $url');
      return null;
    }
    final debtJson = jsonDecode(debtData);
    if (debtJson == null) {
      log.severe('Failed to parse debt data from $url');
      return null;
    }
    final debt = AmountSeries.fromJson(debtJson);
    log.info('Debt data downloaded successfully from $url');
    return debt;
  }

  /// Fetches and parses the bond rate data into an AmountSeries object.
  Future<AmountSeries?> bondRateData(
    BondRateRegion region,
    BondTerm term,
  ) async {
    const url = '$macrodashServerUrl/sov/bond_rates';

    final queryParameters = {'region': region.name, 'term': term.name};
    final bondRateData = await downloadFile(url, queryParameters);
    if (bondRateData == null) {
      log.severe('Failed to download bond rate data from $url');
      return null;
    }
    final bondRateJson = jsonDecode(bondRateData);
    if (bondRateJson == null) {
      log.severe('Failed to parse bond rate data from $url');
      return null;
    }
    final bondRates = AmountSeries.fromJson(bondRateJson);
    log.info('Bond rate data downloaded successfully from $url');
    return bondRates;
  }

  /// Fetches and parses the market index data into an AmountSeries object.
  Future<AmountSeries?> marketIndexData(
    MarketIndexRegion region,
    MarketIndex index,
    DataRange range,
  ) async {
    const url = '$macrodashServerUrl/market/idx';

    final queryParameters = {
      'region': region.name,
      'index': index.name,
      'range': range.name,
    };
    final marketIndexData = await downloadFile(url, queryParameters);
    if (marketIndexData == null) {
      log.severe('Failed to download market index data from $url');
      return null;
    }
    final marketIndexJson = jsonDecode(marketIndexData);
    if (marketIndexJson == null) {
      log.severe('Failed to parse market index data from $url');
      return null;
    }
    final marketIndex = AmountSeries.fromJson(marketIndexJson);
    log.info('Market index data downloaded successfully from $url');
    return marketIndex;
  }

  /// Generic function to fetch AmountSeries based on the enum type.
  Future<AmountSeries?> fetchAmountSeries<T extends Enum, C extends Enum>(
    T region,
    C? category,
    DataRange range,
  ) async {
    if (region is M2Region) {
      return await m2Data(region);
    } else if (region is DebtRegion) {
      return await debtData(region);
    } else if (region is BondRateRegion) {
      if (category == null) {
        log.severe('Category is required for BondRateRegion');
        return null;
      }
      if (category is! BondTerm) {
        log.severe('Category must be of type BondTerm');
        return null;
      }
      return await bondRateData(region, category);
    } else if (region is MarketIndexRegion) {
      if (category == null) {
        log.severe('Category is required for MarketIndexRegion');
        return null;
      }
      if (category is! MarketIndex) {
        log.severe('Category must be of type MarketIndex');
        return null;
      }
      return await marketIndexData(region, category, range);
    } else {
      log.severe('Unsupported region type: ${region.runtimeType}');
      return null;
    }
  }
}
