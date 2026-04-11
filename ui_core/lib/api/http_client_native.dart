import 'package:connectrpc/connect.dart';
import 'package:connectrpc/http2.dart' as http2;

HttpClient createPlatformHttpClient() => http2.createHttpClient();
