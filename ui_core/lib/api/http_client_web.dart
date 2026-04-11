import 'package:connectrpc/connect.dart';
import 'package:connectrpc/web.dart' as web;

HttpClient createPlatformHttpClient() => web.createHttpClient();
