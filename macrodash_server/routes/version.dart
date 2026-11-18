import 'package:dart_frog/dart_frog.dart';

import 'package:macrodash_models/models.dart';

const version = 15;
const minClientVersion = 15;

Response onRequest(RequestContext context) {
  return Response.json(
    body:
        const VersionInfo(version: version, minClientVersion: minClientVersion)
            .toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}
