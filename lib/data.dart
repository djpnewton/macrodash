import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:macrodash_models/models.dart';

import 'config.dart';

class DataDownloader {
  final Logger log = Logger('DataDownloader');

  /// Downloads a file from the given [url] and returns its content as a [String].
  Future<String?> downloadFile(String url) async {
    try {
      // Fetch the file from the URL
      final response = await http.get(Uri.parse(url));

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

  /// Fetches and parses the M2 data into a list of M2Entry objects.
  Future<List<M2Entry>?> m2Data() async {
    const url = '$macrodashServerUrl/fred/m2';

    final m2data = await downloadFile(url);
    if (m2data == null) {
      log.severe('Failed to download M2 data from $url');
      return null;
    }
    final m2json = jsonDecode(m2data);
    if (m2json == null) {
      log.severe('Failed to parse M2 data from $url');
      return null;
    }
    List<M2Entry> m2 =
        m2json.map<M2Entry>((e) {
          return M2Entry.fromJson(e);
        }).toList();
    log.info('M2 data downloaded successfully from $url');
    return m2;
  }
}
