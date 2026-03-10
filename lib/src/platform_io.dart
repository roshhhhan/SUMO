import 'dart:io' show Platform;

String getHost() {
  return Platform.isAndroid ? '10.0.2.2' : 'localhost';
}
