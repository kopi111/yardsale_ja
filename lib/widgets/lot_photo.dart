import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// One photograph of a lot, drawn from whatever form the path takes.
///
/// A lot's photograph reaches us in one of three shapes and every screen in
/// the app has to read all three, so the reading happens here and nowhere
/// else:
///
/// * a `data:` URI — what the seller uploaded, carried inline so it survives
///   a reload and renders on the web build as readily as on a device;
/// * an `http(s)` URL — the stock photograph a demo lot was seeded with;
/// * a filesystem path — a device photograph on the mobile build.
class LotPhoto extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder onUnreadable;

  const LotPhoto({
    super.key,
    required this.path,
    required this.onUnreadable,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  static bool isUploadedPhoto(String path) => path.startsWith('data:');

  @override
  Widget build(BuildContext context) {
    if (isUploadedPhoto(path)) return _uploaded(context);
    if (path.startsWith('http')) return _fromNetwork();
    if (kIsWeb) return onUnreadable(context);
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, _, _) => onUnreadable(context),
    );
  }

  Widget _uploaded(BuildContext context) {
    final bytes = _bytesOf(path);
    if (bytes == null) return onUnreadable(context);
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      // A lot screen rebuilds every second while its clock runs. Without this
      // the photograph is dropped and re-resolved on each rebuild and never
      // finishes painting.
      gaplessPlayback: true,
      errorBuilder: (context, _, _) => onUnreadable(context),
    );
  }

  /// The decoded bytes for a photograph.
  /// The decoded bytes for a photograph, decoded once. Decoding inside
  /// `build` re-ran on every rebuild of a screen whose clock ticks each second.
  static final Map<String, Uint8List?> _decoded = {};

  static Uint8List? _bytesOf(String dataUri) =>
      _decoded.putIfAbsent(dataUri, () => _decode(dataUri));

  Widget _fromNetwork() => Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, _, _) => onUnreadable(context),
      );

  /// The bytes behind a `data:` URI, or null if the text is not one we wrote.
  static Uint8List? _decode(String dataUri) {
    final separator = dataUri.indexOf(',');
    if (separator < 0) return null;
    try {
      return base64Decode(dataUri.substring(separator + 1));
    } on FormatException {
      return null;
    }
  }
}
