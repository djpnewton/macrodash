import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_server/abstract_downloader.dart';

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

  /// Downloads the latest US Bond Rate data in CSV format from the treasury
  /// website
  Future<String?> _downloadUsBondRateData(
    int year,
  ) async {
    final queryParameters = {
      '_format': 'csv',
      'type': 'daily_treasury_yield_curve',
      'field_tdr_date_value': year.toString(),
    };

    final url =
        'https://home.treasury.gov/resource-center/data-chart-center/interest-rates/daily-treasury-rates.csv/$year/all';
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

    return _parseEcbM2Data(jsonData, '0:0:0:0:0', 0.001, 1 / rate);
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
      0.000001,
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
        final date = DateTime.parse(dateStart);
        // ignore: avoid_dynamic_calls
        final amount = entry.value[0] as num;
        return AmountEntry(
          date: date,
          amount: amount.toDouble() *
              scale *
              xxxUsdRate, // convert to trillions of dollars
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
              return AmountEntry(date: date, amount: amount * 0.001);
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
    // Get the current year
    final year = DateTime.now().year;
    // Get the last 5 years of data
    final bond30yData = <AmountEntry>[];
    final bond20yData = <AmountEntry>[];
    final bond10yData = <AmountEntry>[];
    final bond5yData = <AmountEntry>[];
    final bond1yData = <AmountEntry>[];
    for (var i = 0; i < 5; i++) {
      final yearToFetch = year - i;
      final csvData = await _downloadUsBondRateData(yearToFetch);
      if (csvData == null) {
        _log.warning('Failed to fetch US Bond Rate data.');
        return null;
      }
      // Parse the CSV data
      final rows = const CsvToListConverter().convert(csvData, eol: '\n');
      if (rows.isEmpty) {
        _log.warning('No data found in the CSV.');
        return null;
      }
      // Extract the header row
      // header row has the format: Date	1 Mo	1.5 Month	2 Mo	3 Mo	4 Mo	6 Mo
      //	1 Yr	2 Yr	3 Yr	5 Yr	7 Yr	10 Yr	20 Yr	30 Yr
      final headers = rows.first.cast<String>();
      _log.info('CSV headers: $headers');
      final dateIndex = headers.indexOf('Date');
      final bond30yIndex = headers.indexOf('30 Yr');
      final bond20yIndex = headers.indexOf('20 Yr');
      final bond10yIndex = headers.indexOf('10 Yr');
      final bond5yIndex = headers.indexOf('5 Yr');
      final bond1yIndex = headers.indexOf('1 Yr');
      if (dateIndex == -1 ||
          bond30yIndex == -1 ||
          bond20yIndex == -1 ||
          bond10yIndex == -1 ||
          bond5yIndex == -1 ||
          bond1yIndex == -1) {
        _log.warning(
          'Required fields not found in the CSV.',
        );
        return null;
      }
      // Extract the data
      for (final row in rows.skip(1)) {
        try {
          // parse date in format MM/DD/YYYY
          final date =
              DateFormat('MM/dd/yyyy').parse(row[dateIndex]!.toString());
          final bond30y = double.tryParse(row[bond30yIndex]!.toString());
          if (bond30y != null) {
            bond30yData.insert(0, AmountEntry(date: date, amount: bond30y));
          }
          final bond20y = double.tryParse(row[bond20yIndex]!.toString());
          if (bond20y != null) {
            bond20yData.insert(0, AmountEntry(date: date, amount: bond20y));
          }
          final bond10y = double.tryParse(row[bond10yIndex]!.toString());
          if (bond10y != null) {
            bond10yData.insert(0, AmountEntry(date: date, amount: bond10y));
          }
          final bond5y = double.tryParse(row[bond5yIndex]!.toString());
          if (bond5y != null) {
            bond5yData.insert(0, AmountEntry(date: date, amount: bond5y));
          }
          final bond1y = double.tryParse(row[bond1yIndex]!.toString());
          if (bond1y != null) {
            bond1yData.insert(0, AmountEntry(date: date, amount: bond1y));
          }
        } catch (e) {
          _log.warning('Error parsing row: $row. Skipping. Error: $e');
        }
      }
    }
    _log.info('US Bond Rate data parsed successfully.');
    return [
      BondRateData(term: BondTerm.thirtyYear, data: bond30yData),
      BondRateData(term: BondTerm.twentyYear, data: bond20yData),
      BondRateData(term: BondTerm.tenYear, data: bond10yData),
      BondRateData(term: BondTerm.fiveYear, data: bond5yData),
      BondRateData(term: BondTerm.oneYear, data: bond1yData),
    ];
  }
}
