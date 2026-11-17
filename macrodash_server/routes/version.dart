import 'package:dart_frog/dart_frog.dart';

import 'package:macrodash_models/models.dart';

const version = 14;
const minClientVersion = 14;

Response onRequest(RequestContext context) {
  return Response.json(
    body:
        const VersionInfo(version: version, minClientVersion: minClientVersion)
            .toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}
