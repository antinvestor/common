import 'package:logger/logger.dart';

final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

class AppLogger {
  AppLogger._();

  static void debug(String message, {Map<String, dynamic>? data}) {
    _logger.d(data != null ? '$message $data' : message);
  }

  static void info(String message, {Map<String, dynamic>? data}) {
    _logger.i(data != null ? '$message $data' : message);
  }

  static void warning(String message, {Map<String, dynamic>? data}) {
    _logger.w(data != null ? '$message $data' : message);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    _logger.e(
      data != null ? '$message $data' : message,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
