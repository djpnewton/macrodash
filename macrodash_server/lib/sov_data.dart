import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_server/abstract_downloader.dart';
import 'package:quiver/time.dart';

/// Wrap AmountSeries with a bond term
class BondRateData {
  /// Creates an instance of [BondRateData] with the provided term and data.
  const BondRateData({required this.term, required this.data});

  /// the bond term
  final BondTerm term;

  /// the data for the bond term
  final List<AmountEntry> data;
}

/// A class that handles downloading and parsing data from various sources.
/// It provides methods to download and parse data related to M2 money supply,
/// exchange rates, and sovereign debt.
class SovData extends AbstractDownloader {
  /// Creates an instance of [SovData] with the provided FRED API key.
  SovData({required String fredApiKey}) : _fredApiKey = fredApiKey;

  /// FRED data source
  static const String fredSource = 'https://fred.stlouisfed.org/';

  /// ECB data source
  static const String ecbSource = 'https://www.ecb.europa.eu/';

  /// US Treasury data source
  static const String usTreasurySource = 'https://fiscaldata.treasury.gov/';

  final String _fredApiKey;
  final Logger _log = Logger('SovData');

  Future<String?> _downloadFredJapUsdData() async {
    const url = 'https://api.stlouisfed.org/fred/series/observations';
    final queryParameters = {
      'series_id': 'DEXJPUS',
      'api_key': _fredApiKey,
      'file_type': 'json',
    };

    return downloadFile(url, queryParameters);
  }

  /// Downloads the latest JAPAN M2 data in JSON format from the ECB API
  Future<String?> _downloadJapanM2Data() async {
    const url =
        'https://sdw-wsrest.ecb.europa.eu/service/data/RTD/M.JP.Y.M_M2.J';
    return downloadFile(url, {'format': 'jsondata'});
  }

  /// Downloads the latest USD/EUR data in JSON format from the ECB API
  Future<String?> downloadEcbUsdEuroData() async {
    const url =
        'https://sdw-wsrest.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A';
    return downloadFile(url, {'format': 'jsondata'});
  }

  /// Downloads the latest EU M2 data in JSON format from the ECB API
  Future<String?> _downloadEcbM2Data() async {
    const url =
        'https://sdw-wsrest.ecb.europa.eu/service/data/BSI/M.U2.Y.V.M20.X.1.U2.2300.Z01.E';
    return downloadFile(url, {'format': 'jsondata'});
  }

  /// Downloads the latest USA M2 data in CSV format from the FRED API and
  /// unzips it.
  Future<String?> _downloadFredM2Data() async {
    const url = 'https://api.stlouisfed.org/fred/series/observations';
    final queryParameters = {
      'series_id': 'M2SL',
      'api_key': _fredApiKey,
      'file_type': 'csv',
    };

    final uri = Uri.parse(url).replace(queryParameters: queryParameters);

    try {
      // Download the zipped file
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        _log.info('M2 data downloaded successfully from $uri');

        // Unzip the file
        final archive = ZipDecoder().decodeBytes(response.bodyBytes);
        final csvFile = archive.files.firstWhere(
          (file) => file.name.endsWith('.csv'),
          orElse: () => throw Exception('No CSV file found in the archive.'),
        );

        // Decode the CSV file content
        final csvData = utf8.decode(csvFile.content as List<int>);
        _log.info('CSV data extracted successfully.');
        return csvData;
      } else {
        _log.warning(
          'Failed to download M2 data. Status code: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      _log.severe('Error downloading or unzipping M2 data: $e');
      return null;
    }
  }

  /// Downloads the latest US Debt data in JSON format from the treasury API
  Future<String?> _downloadUsDebtData({int? pageNumber, int? pageSize}) async {
    final queryParameters = {
      'format': 'json',
    };
    if (pageNumber != null) {
      queryParameters['page[number]'] = pageNumber.toString();
    }
    if (pageSize != null) {
      queryParameters['page[size]'] = pageSize.toString();
    }
    const url =
        'https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v2/accounting/od/debt_to_penny';
    return downloadFile(url, queryParameters);
  }

  /// Downloads the latest US Bond Rate data in JSON format from the treasury
  /// API
  Future<String?> _downloadUsBondRateData({
    int? pageNumber,
    int? pageSize,
  }) async {
    final queryParameters = {
      'format': 'json',
    };
    if (pageNumber != null) {
      queryParameters['page[number]'] = pageNumber.toString();
    }
    if (pageSize != null) {
      queryParameters['page[size]'] = pageSize.toString();
    }
    const url =
        'https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/accounting/od/auctions_query';
    return downloadFile(url, queryParameters);
  }

  /// Fetches and parses the Jap/US Dollar exchange rate
  Future<double?> japUsdRate() async {
    final jsonData = await _downloadFredJapUsdData();
    if (jsonData == null) {
      _log.warning('Failed to fetch JAP/USD data.');
      return null;
    }

    try {
      // Parse the JSON data
      final parsedJson = jsonDecode(jsonData);

      // ignore: avoid_dynamic_calls
      final observations = parsedJson['observations'] as List<dynamic>;
      // Extract the latest exchange rate
      final latestEntry = observations.last;
      // ignore: avoid_dynamic_calls
      final amount = double.parse(latestEntry['value'] as String);

      _log.info('JAP/USD exchange rate fetched successfully ($amount).');
      return amount;
    } catch (e) {
      _log.severe('Error parsing JAP/USD exchange rate: $e');
      return null;
    }
  }

  /// Fetches and parses the ECB Euro/US Dollar exchange rate
  Future<double?> ecbUsdEuroRate() async {
    final jsonData = await downloadEcbUsdEuroData();
    if (jsonData == null) {
      _log.warning('Failed to fetch USD/EUR data.');
      return null;
    }

    try {
      // Parse the JSON data
      final parsedJson = jsonDecode(jsonData);
      // ignore: avoid_dynamic_calls
      final seriesAmounts = parsedJson['dataSets'][0]['series']['0:0:0:0:0']
          ['observations'] as Map<String, dynamic>;
      // Extract the latest exchange rate
      final latestEntry = seriesAmounts.entries.last;
      // ignore: avoid_dynamic_calls
      final amount = latestEntry.value[0] as double;

      _log.info('USD/EUR exchange rate fetched successfully ($amount).');
      return amount;
    } catch (e) {
      _log.severe('Error parsing USD/EUR exchange rate: $e');
      return null;
    }
  }

  /// Fetches and parses the ECB M2 data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> japM2Data() async {
    final rate = await japUsdRate();
    if (rate == null) {
      _log.warning('Failed to fetch Jap/USD exchange rate.');
      return null;
    }

    final jsonData = await _downloadJapanM2Data();
    if (jsonData == null) {
      _log.warning('Failed to fetch M2 data.');
      return null;
    }

    return _parseEcbM2Data(jsonData, '0:0:0:0:0', 1, 1 / rate);
  }

  /// Fetches and parses the ECB M2 data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> ecbM2Data() async {
    final rate = await ecbUsdEuroRate();
    if (rate == null) {
      _log.warning('Failed to fetch USD/EUR exchange rate.');
      return null;
    }

    final jsonData = await _downloadEcbM2Data();
    if (jsonData == null) {
      _log.warning('Failed to fetch M2 data.');
      return null;
    }

    return _parseEcbM2Data(
      jsonData,
      '0:0:0:0:0:0:0:0:0:0:0',
      0.001,
      rate,
    );
  }

  List<AmountEntry>? _parseEcbM2Data(
    String jsonData,
    String seriesObsRubbish,
    double scale,
    double xxxUsdRate,
  ) {
    try {
      // Parse the JSON data
      final parsedJson = jsonDecode(jsonData);
      // ignore: avoid_dynamic_calls
      final seriesAmounts = parsedJson['dataSets'][0]['series']
          [seriesObsRubbish]['observations'] as Map<String, dynamic>;
      // ignore: avoid_dynamic_calls
      final seriesDates = parsedJson['structure']['dimensions']['observation']
          [0]['values'] as List<dynamic>;
      // Extract the data
      final data = seriesAmounts.entries.map((entry) {
        final i = int.parse(entry.key);
        // ignore: avoid_dynamic_calls
        final dateStart = seriesDates[i]['start'] as String;
        var date = DateTime.parse(dateStart);
        // TODO(djpnewton): we should be able to get rid of this once the client
        // has better handling of dates in its grids etc.
        // Adjust the date if it is the last hour of the last day of the month
        if (date.hour >= 22 && date.day == daysInMonth(date.year, date.month)) {
          var newYear = date.year;
          var newMonth = date.month + 1;
          if (date.month > 12) {
            newYear++;
            newMonth = 1;
          }
          date = DateTime(newYear, newMonth);
        } else {
          _log.warning('date not converted to first day of the month: $date');
        }
        // ignore: avoid_dynamic_calls
        final amount = entry.value[0] as num;
        return AmountEntry(
          date: date,
          amount: amount.toDouble() *
              scale *
              xxxUsdRate, // convert to billions of dollars
        );
      }).toList();

      _log.info('M2 data parsed successfully.');
      return data;
    } catch (e) {
      _log.severe('Error parsing M2 data: $e');
      return null;
    }
  }

  /// Fetches and parses the FRED M2 data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> fredM2Data() async {
    final csvData = await _downloadFredM2Data();
    if (csvData == null) {
      _log.warning('Failed to fetch M2 data.');
      return null;
    }

    try {
      // Parse the CSV data
      final rows = const CsvToListConverter().convert(csvData, eol: '\n');
      if (rows.isEmpty) {
        _log.warning('No data found in the CSV.');
        return null;
      }

      // Extract the header row
      final headers = rows.first.cast<String>();
      _log.info('CSV headers: $headers');
      final periodStartDateIndex = headers.indexOf('period_start_date');
      final m2slIndex = headers.indexOf('M2SL');

      if (periodStartDateIndex == -1 || m2slIndex == -1) {
        _log.warning('Required fields not found in the CSV.');
        return null;
      }

      // Map the rows to a list of AmountEntry objects
      final data = rows
          .skip(1)
          .map((row) {
            try {
              final date = DateTime.parse(
                row[periodStartDateIndex]?.toString() ?? '',
              );
              final amount =
                  double.tryParse(row[m2slIndex]?.toString() ?? '') ?? 0.0;
              return AmountEntry(date: date, amount: amount);
            } catch (e) {
              _log.warning('Error parsing row: $row. Skipping.');
              return null; // Skip invalid rows
            }
          })
          .whereType<AmountEntry>()
          .toList();

      _log.info('M2 data parsed successfully.');
      return data;
    } catch (e) {
      _log.severe('Error parsing M2 data: $e');
      return null;
    }
  }

  /// Fetches and parses the US Debt data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> usDebtData() async {
    var jsonData = await _downloadUsDebtData(pageSize: 10000);
    if (jsonData == null) {
      _log.warning('Failed to fetch US Debt data.');
      return null;
    }

    try {
      // Parse the JSON data
      var parsedJson = jsonDecode(jsonData);
      // ignore: avoid_dynamic_calls
      final links = parsedJson['links'] as Map<String, dynamic>;
      _log.info('Links: $links');
      // Extract the data
      final last = links['last'] as String;
      _log.info('Last link: $last');
      // parse query string 'last'
      final lastParams = Uri.parse('http://example.com?$last').queryParameters;
      _log.info('Last params: $lastParams');
      final pageNumber = int.tryParse(lastParams['page[number]'] ?? '');
      final pageSize = int.tryParse(lastParams['page[size]'] ?? '');
      if (pageNumber == null || pageSize == null) {
        _log.warning('Failed to parse US Debt data.');
        return null;
      }
      // Download the data again with the page number and size
      jsonData = await _downloadUsDebtData(
        pageNumber: pageNumber,
        pageSize: pageSize,
      );
      if (jsonData == null) {
        _log.warning('Failed to fetch US Debt data.');
        return null;
      }
      // Parse the JSON data
      parsedJson = jsonDecode(jsonData);
      // ignore: avoid_dynamic_calls
      final observations = parsedJson['data'] as List<dynamic>;
      // Extract the data
      final data = observations.map((entry) {
        // ignore: avoid_dynamic_calls
        final date = DateTime.parse(entry['record_date'] as String);
        // ignore: avoid_dynamic_calls
        final amount = double.parse(entry['tot_pub_debt_out_amt'] as String);
        return AmountEntry(date: date, amount: amount / 1000000000000);
      }).toList();

      _log.info('US Debt data parsed successfully.');
      return data;
    } catch (e) {
      _log.severe('Error parsing US Debt data: $e');
      return null;
    }
  }

  /// Fetches and parses the US Bond Rate data into a list of AmountEntry
  /// objects.
  Future<List<BondRateData>?> usBondRateData() async {
    var jsonData = await _downloadUsBondRateData(pageSize: 10000);
    if (jsonData == null) {
      _log.warning('Failed to fetch US Bond Rate data.');
      return null;
    }

    try {
      // Parse the JSON data
      var parsedJson = jsonDecode(jsonData);
      // ignore: avoid_dynamic_calls
      final links = parsedJson['links'] as Map<String, dynamic>;
      _log.info('Links: $links');
      // Extract the data
      final last = links['last'] as String;
      _log.info('Last link: $last');
      // parse query string 'last'
      final lastParams = Uri.parse('http://example.com?$last').queryParameters;
      _log.info('Last params: $lastParams');
      final pageNumber = int.tryParse(lastParams['page[number]'] ?? '');
      final pageSize = int.tryParse(lastParams['page[size]'] ?? '');
      if (pageNumber == null || pageSize == null) {
        _log.warning('Failed to parse US Bond Rate data.');
        return null;
      }
      // Download the data again with the page number and size
      jsonData = await _downloadUsBondRateData(
        pageNumber: pageNumber,
        pageSize: pageSize,
      );
      if (jsonData == null) {
        _log.warning('Failed to fetch US Bond Rate data.');
        return null;
      }
      // Parse the JSON data
      parsedJson = jsonDecode(jsonData);
      // ignore: avoid_dynamic_calls
      final observations = parsedJson['data'] as List<dynamic>;
      // Extract the data
      final bond30yData = <AmountEntry>[];
      final bond20yData = <AmountEntry>[];

      for (final entry in observations) {
        // ignore: avoid_dynamic_calls
        final securityType = entry['security_type'] as String;
        // ignore: avoid_dynamic_calls
        final securityTerm = entry['security_term'] as String;

        if (securityType != 'Bond') {
          continue;
        }
        if (securityTerm != '30-Year' && securityTerm != '20-Year') {
          continue;
        }

        // ignore: avoid_dynamic_calls
        final date = DateTime.parse(entry['record_date'] as String);
        // ignore: avoid_dynamic_calls
        final amount = double.parse(entry['avg_med_yield'] as String);

        if (securityType == 'Bond' && securityTerm == '30-Year') {
          bond30yData.add(AmountEntry(date: date, amount: amount));
        }
        if (securityType == 'Bond' && securityTerm == '20-Year') {
          bond20yData.add(AmountEntry(date: date, amount: amount));
        }
      }

      _log.info('US Bond Rate data parsed successfully.');
      return [
        BondRateData(term: BondTerm.thirtyYear, data: bond30yData),
        BondRateData(term: BondTerm.twentyYear, data: bond20yData),
      ];
    } catch (e) {
      _log.severe('Error parsing US Bond Rate data: $e');
      return null;
    }
  }
}
