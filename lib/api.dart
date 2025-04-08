import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:macrodash_models/models.dart';

import 'config.dart';

class ServerApi {
  final Logger log = Logger('DataDownloader');

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

  /// Fetches and parses the M2 data into a AmountSeries object.
  Future<AmountSeries?> m2Data(M2Region region) async {
    const url = '$macrodashServerUrl/fred/m2';

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
}
