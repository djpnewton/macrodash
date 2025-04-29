import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf_cors;
import 'package:shelf_static/shelf_static.dart' as shelf_static;

/// Creates a [Handler] that serves static files (with CORS header) within
/// provided [path].
Handler createStaticFileHandlerWithCors({String path = 'public'}) {
  final cors = shelf_cors.corsHeaders(
    headers: {
      shelf_cors.ACCESS_CONTROL_ALLOW_ORIGIN: '*',
    },
  );

  return fromShelfHandler(
    const shelf.Pipeline()
        .addMiddleware(cors)
        .addHandler(shelf_static.createStaticHandler(path)),
  );
}

/// main entry point for the Dart Frog application.
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) {
  final cascade = Cascade().add(createStaticFileHandlerWithCors()).add(handler);
  return serve(cascade.handler, ip, port);
}
