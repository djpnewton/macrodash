import 'package:dart_frog/dart_frog.dart';

import 'package:macrodash_models/models.dart';

const version = 8;
const minClientVersion = 8;

Response onRequest(RequestContext context) {
  return Response.json(
    body:
        const VersionInfo(version: version, minClientVersion: minClientVersion)
            .toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}
