import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Abstract class for downloading files from a URL.
abstract class AbstractDownloader {
  final Logger _log = Logger('AbstractDownloader');

  /// Downloads a file from the given [url] with optional [queryParameters].
  /// Returns the file content as a [String], or `null` if the download fails.
  Future<String?> downloadFile(
    String url,
    Map<String, dynamic>? queryParameters,
  ) async {
    try {
      var uri = Uri.parse(url);
      if (queryParameters != null) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      _log.info('Downloading file from $url with params: $queryParameters');

      // Fetch the file from the URL
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        _log.info('File downloaded successfully from $url');
        return response.body; // Return the file content as a String
      } else {
        _log.warning(
          'Failed to download file. Status code: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      _log.severe('Error downloading file: $e');
      return null;
    }
  }
}
