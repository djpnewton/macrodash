import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf;

final Logger log = Logger('root_middleware');

Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use(
        fromShelfMiddleware(
          shelf.corsHeaders(
            headers: {
              shelf.ACCESS_CONTROL_ALLOW_ORIGIN: '*',
            },
          ),
        ),
      );
}
