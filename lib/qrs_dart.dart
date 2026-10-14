/// Dart port of [Qrs](https://github.com/qifi-dev/qrs): stream arbitrary data
/// through a sequence of QR codes.
///
/// ```dart
/// import 'dart:typed_data';
/// import 'package:qrs_dart/qrs_dart.dart';
///
/// void main() {
///   final session = SendSession.forFile(
///     Uint8List.fromList(utf8.encode('hello')),
///     filename: 'hello.txt',
///     contentType: 'text/plain',
///   );
///
///   final frame = session.next();      // repeat for every QR frame
///   print(frame.qr.data.length);       // modules per side
/// }
/// ```
library;

export 'generate.dart';
export 'gif.dart';
export 'luby_transform.dart';
export 'receiver.dart';
export 'sender.dart';
export 'slicing.dart';
export 'uqr.dart';
