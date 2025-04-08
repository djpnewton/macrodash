import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:macrodash_models/models.dart';

import '_middleware.dart';

class DataDownloader {
  DataDownloader({required this.fredApiKey});

  final String fredApiKey;
  final Logger log = Logger('DataDownloader');

  /// Downloads a file from the given [url] and returns its content as a
  /// [String].
  Future<String?> downloadFile(String url) async {
    try {
      // Fetch the file from the URL
      final response = await http.get(Uri.parse(url));

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

  /// Downloads the latest M2 data in CSV format from the FRED API and unzips
  /// it.
  Future<String?> downloadM2Data() async {
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

  /// Fetches and parses the M2 data into a list of FredM2Entry objects.
  Future<List<M2Entry>?> m2Data() async {
    final csvData = await downloadM2Data();
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
      final periodStartDateIndex = headers.indexOf('period_start_date');
      final m2slIndex = headers.indexOf('M2SL');

      if (periodStartDateIndex == -1 || m2slIndex == -1) {
        log.warning('Required fields not found in the CSV.');
        return null;
      }

      // Map the rows to a list of FredM2Entry objects
      final data = rows
          .skip(1)
          .map((row) {
            try {
              final date = DateTime.parse(
                row[periodStartDateIndex]?.toString() ?? '',
              );
              final amount =
                  double.tryParse(row[m2slIndex]?.toString() ?? '') ?? 0.0;
              return M2Entry(date: date, amount: amount);
            } catch (e) {
              log.warning('Error parsing row: $row. Skipping.');
              return null; // Skip invalid rows
            }
          })
          .whereType<M2Entry>()
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
  final fredApiKey = context.read<FredConfig>().apiKey;
  final dataDownloader = DataDownloader(fredApiKey: fredApiKey);
  final m2Data = await dataDownloader.m2Data();
  if (m2Data == null) {
    return Response(
      statusCode: 500,
      body: 'Failed to fetch M2 data.',
    );
  }
  return Response.json(
    body: m2Data.map((entry) => entry.toJson()).toList(),
    headers: {
      'Content-Type': 'application/json',
    },
  );
}
