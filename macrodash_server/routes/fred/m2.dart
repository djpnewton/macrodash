import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:quiver/time.dart';

import '_middleware.dart';

class DataDownloader {
  DataDownloader({required this.fredApiKey});

  static const String fredSource = 'https://fred.stlouisfed.org/';
  static const String ecbSource = 'https://www.ecb.europa.eu/';
  final String fredApiKey;
  final Logger log = Logger('DataDownloader');

  /// Downloads a file from the given [url] and returns its content as a
  /// [String].
  Future<String?> downloadFile(
    String url,
    Map<String, dynamic>? queryParameters,
  ) async {
    try {
      var uri = Uri.parse(url);
      if (queryParameters != null) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      log.info('Downloading file from $url with params: $queryParameters');

      // Fetch the file from the URL
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        log.info('File downloaded successfully from $url');
        return response.body; // Return the file content as a String
      } else {
        log.warning(
          'Failed to download file. Status code: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      log.severe('Error downloading file: $e');
      return null;
    }
  }

  Future<String?> downloadFredJapUsdData() async {
    const url = 'https://api.stlouisfed.org/fred/series/observations';
    final queryParameters = {
      'series_id': 'DEXJPUS',
      'api_key': fredApiKey,
      'file_type': 'json',
    };

    return downloadFile(url, queryParameters);
  }

  /// Downloads the latest JAPAN M2 data in JSON format from the ECB API
  Future<String?> downloadJapanM2Data() async {
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
  Future<String?> downloadEcbM2Data() async {
    const url =
        'https://sdw-wsrest.ecb.europa.eu/service/data/BSI/M.U2.Y.V.M20.X.1.U2.2300.Z01.E';
    return downloadFile(url, {'format': 'jsondata'});
  }

  /// Downloads the latest USA M2 data in CSV format from the FRED API and
  /// unzips it.
  Future<String?> downloadFredM2Data() async {
    const url = 'https://api.stlouisfed.org/fred/series/observations';
    final queryParameters = {
      'series_id': 'M2SL',
      'api_key': fredApiKey,
      'file_type': 'csv',
    };

    final uri = Uri.parse(url).replace(queryParameters: queryParameters);

    try {
      // Download the zipped file
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        log.info('M2 data downloaded successfully from $uri');

        // Unzip the file
        final archive = ZipDecoder().decodeBytes(response.bodyBytes);
        final csvFile = archive.files.firstWhere(
          (file) => file.name.endsWith('.csv'),
          orElse: () => throw Exception('No CSV file found in the archive.'),
        );

        // Decode the CSV file content
        final csvData = utf8.decode(csvFile.content as List<int>);
        log.info('CSV data extracted successfully.');
        return csvData;
      } else {
        log.warning(
          'Failed to download M2 data. Status code: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      log.severe('Error downloading or unzipping M2 data: $e');
      return null;
    }
  }

  /// Fetches and parses the Jap/US Dollar exchange rate
  Future<double?> japUsdRate() async {
    final jsonData = await downloadFredJapUsdData();
    if (jsonData == null) {
      log.warning('Failed to fetch JAP/USD data.');
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

      log.info('JAP/USD exchange rate fetched successfully ($amount).');
      return amount;
    } catch (e) {
      log.severe('Error parsing JAP/USD exchange rate: $e');
      return null;
    }
  }

  /// Fetches and parses the ECB Euro/US Dollar exchange rate
  Future<double?> ecbUsdEuroRate() async {
    final jsonData = await downloadEcbUsdEuroData();
    if (jsonData == null) {
      log.warning('Failed to fetch USD/EUR data.');
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

      log.info('USD/EUR exchange rate fetched successfully ($amount).');
      return amount;
    } catch (e) {
      log.severe('Error parsing USD/EUR exchange rate: $e');
      return null;
    }
  }

  /// Fetches and parses the ECB M2 data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> japM2Data() async {
    final rate = await japUsdRate();
    if (rate == null) {
      log.warning('Failed to fetch Jap/USD exchange rate.');
      return null;
    }

    final jsonData = await downloadJapanM2Data();
    if (jsonData == null) {
      log.warning('Failed to fetch M2 data.');
      return null;
    }

    return parseEcbM2Data(jsonData, '0:0:0:0:0', 1, 1 / rate);
  }

  /// Fetches and parses the ECB M2 data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> ecbM2Data() async {
    final rate = await ecbUsdEuroRate();
    if (rate == null) {
      log.warning('Failed to fetch USD/EUR exchange rate.');
      return null;
    }

    final jsonData = await downloadEcbM2Data();
    if (jsonData == null) {
      log.warning('Failed to fetch M2 data.');
      return null;
    }

    return parseEcbM2Data(
      jsonData,
      '0:0:0:0:0:0:0:0:0:0:0',
      0.001,
      rate,
    );
  }

  List<AmountEntry>? parseEcbM2Data(
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
          log.warning('date not converted to first day of the month: $date');
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

      log.info('M2 data parsed successfully.');
      return data;
    } catch (e) {
      log.severe('Error parsing M2 data: $e');
      return null;
    }
  }

  /// Fetches and parses the FRED M2 data into a list of AmountEntry objects.
  Future<List<AmountEntry>?> fredM2Data() async {
    final csvData = await downloadFredM2Data();
    if (csvData == null) {
      log.warning('Failed to fetch M2 data.');
      return null;
    }

    try {
      // Parse the CSV data
      final rows = const CsvToListConverter().convert(csvData, eol: '\n');
      if (rows.isEmpty) {
        log.warning('No data found in the CSV.');
        return null;
      }

      // Extract the header row
      final headers = rows.first.cast<String>();
      log.info('CSV headers: $headers');
      final periodStartDateIndex = headers.indexOf('period_start_date');
      final m2slIndex = headers.indexOf('M2SL');

      if (periodStartDateIndex == -1 || m2slIndex == -1) {
        log.warning('Required fields not found in the CSV.');
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
              log.warning('Error parsing row: $row. Skipping.');
              return null; // Skip invalid rows
            }
          })
          .whereType<AmountEntry>()
          .toList();

      log.info('M2 data parsed successfully.');
      return data;
    } catch (e) {
      log.severe('Error parsing M2 data: $e');
      return null;
    }
  }
}

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the region parameter into the Region enum
  final regionParam = params['region']?.toLowerCase();
  final region = M2Region.values.firstWhere(
    (r) => r.name == regionParam,
    orElse: () => M2Region.all,
  );

  final fredApiKey = context.read<FredConfig>().apiKey;
  final dataDownloader = DataDownloader(fredApiKey: fredApiKey);

  // Fetch data based on the region
  List<AmountEntry>? m2Data;
  switch (region) {
    case M2Region.japan:
      m2Data = await dataDownloader.japM2Data();
    case M2Region.euro:
      m2Data = await dataDownloader.ecbM2Data();
    case M2Region.usa:
      m2Data = await dataDownloader.fredM2Data();
    case M2Region.all:
      // Combine data from all sources for ALL
      final usaData = await dataDownloader.fredM2Data();
      final ecbData = await dataDownloader.ecbM2Data();
      final japData = await dataDownloader.japM2Data();

      if (usaData != null && ecbData != null && japData != null) {
        // Combine data by matching dates and summing amounts
        final usdMap = {for (final entry in usaData) entry.date: entry.amount};
        final japMap = {for (final entry in japData) entry.date: entry.amount};
        final combinedData = ecbData
            .where(
          (entry) =>
              usdMap.containsKey(entry.date) && japMap.containsKey(entry.date),
        )
            .map((entry) {
          final combinedAmount = entry.amount +
              (usdMap[entry.date] ?? 0.0) +
              (japMap[entry.date] ?? 0.0);
          return AmountEntry(date: entry.date, amount: combinedAmount);
        }).toList();

        m2Data = combinedData;
      } else {
        m2Data = null;
      }
  }

  if (m2Data == null) {
    return Response(statusCode: 500, body: 'Failed to fetch M2 data.');
  }

  final sources = [
    if (region == M2Region.usa || region == M2Region.all)
      DataDownloader.fredSource,
    if (region == M2Region.euro ||
        region == M2Region.japan ||
        region == M2Region.all)
      DataDownloader.ecbSource,
  ];

  final result = AmountSeries(
    description: 'Billions of Dollars',
    sources: sources,
    data: m2Data,
  );

  return Response.json(
    body: result.toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}
