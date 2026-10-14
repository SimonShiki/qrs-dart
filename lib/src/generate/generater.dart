import 'dart:typed_data';

import '../luby_transform/luby_transform.dart';
import '../uqr/uqr.dart';
import 'base_generater.dart';
import 'shared.dart';

/// Generater options for [createGeneraterQRCodeArray].
class QrArrayGeneraterOptions extends QrCodeGenerateOptions
    with GeneraterBaseOptions {
  /// Creates options for a 2D-array QR renderer.
  const QrArrayGeneraterOptions({
    super.ecc,
    super.maskPattern,
    super.boostEcc,
    super.minVersion,
    super.maxVersion,
    super.border,
    super.invert,
    super.onEncoded,
    this.sliceSize = generaterDefaultSliceSize,
    this.compress = true,
    this.urlPrefix = '',
  });

  @override
  final int sliceSize;
  @override
  final bool compress;
  @override
  final String urlPrefix;
}

/// Generater options for [createGeneraterUnicode].
class UnicodeGeneraterOptions extends QrCodeGenerateUnicodeOptions
    with GeneraterBaseOptions {
  /// Creates options for a Unicode QR renderer.
  const UnicodeGeneraterOptions({
    super.ecc,
    super.maskPattern,
    super.boostEcc,
    super.minVersion,
    super.maxVersion,
    super.border,
    super.invert,
    super.onEncoded,
    super.whiteChar,
    super.blackChar,
    this.sliceSize = generaterDefaultSliceSize,
    this.compress = true,
    this.urlPrefix = '',
  });

  @override
  final int sliceSize;
  @override
  final bool compress;
  @override
  final String urlPrefix;
}

/// Generater options for [createGeneraterUnicodeCompact].
class UnicodeCompactGeneraterOptions extends QrCodeGenerateOptions
    with GeneraterBaseOptions {
  /// Creates options for a two-rows-per-line Unicode QR renderer.
  const UnicodeCompactGeneraterOptions({
    super.ecc,
    super.maskPattern,
    super.boostEcc,
    super.minVersion,
    super.maxVersion,
    super.border,
    super.invert,
    super.onEncoded,
    this.sliceSize = generaterDefaultSliceSize,
    this.compress = true,
    this.urlPrefix = '',
  });

  @override
  final int sliceSize;
  @override
  final bool compress;
  @override
  final String urlPrefix;
}

/// Generater options for [createGeneraterANSI].
class AnsiGeneraterOptions extends QrCodeGenerateOptions
    with GeneraterBaseOptions {
  /// Creates options for an ANSI-coloured QR renderer.
  const AnsiGeneraterOptions({
    super.ecc,
    super.maskPattern,
    super.boostEcc,
    super.minVersion,
    super.maxVersion,
    super.border,
    super.invert,
    super.onEncoded,
    this.sliceSize = generaterDefaultSliceSize,
    this.compress = true,
    this.urlPrefix = '',
  });

  @override
  final int sliceSize;
  @override
  final bool compress;
  @override
  final String urlPrefix;
}

/// Generater options for [createGeneraterSVG].
class SvgGeneraterOptions extends QrCodeGenerateSvgOptions
    with GeneraterBaseOptions {
  /// Creates options for an SVG QR renderer.
  const SvgGeneraterOptions({
    super.ecc,
    super.maskPattern,
    super.boostEcc,
    super.minVersion,
    super.maxVersion,
    super.border,
    super.invert,
    super.onEncoded,
    super.pixelSize,
    super.whiteColor,
    super.blackColor,
    this.sliceSize = generaterDefaultSliceSize,
    this.compress = true,
    this.urlPrefix = '',
  });

  @override
  final int sliceSize;
  @override
  final bool compress;
  @override
  final String urlPrefix;
}

/// Encode data into QR Codes represented by a 2D array of booleans.
Generater<QrCodeGenerateResult> createGeneraterQRCodeArray(
  Uint8List data, {
  QrArrayGeneraterOptions options = const QrArrayGeneraterOptions(),
}) => createGeneraterWithRender(data, options, _renderQRCodeArray);

/// Render QR Codes with the Unicode `█`/`░` characters.
Generater<String> createGeneraterUnicode(
  Uint8List data, {
  UnicodeGeneraterOptions options = const UnicodeGeneraterOptions(),
}) => createGeneraterWithRender(data, options, _renderUnicode);

/// Render QR Codes with two rows per line using `▀`, `▄`, `█` and space.
Generater<String> createGeneraterUnicodeCompact(
  Uint8List data, {
  UnicodeCompactGeneraterOptions options =
      const UnicodeCompactGeneraterOptions(),
}) => createGeneraterWithRender(data, options, _renderUnicodeCompact);

/// Render QR Codes to ANSI-coloured strings for terminals.
Generater<String> createGeneraterANSI(
  Uint8List data, {
  AnsiGeneraterOptions options = const AnsiGeneraterOptions(),
}) => createGeneraterWithRender(data, options, _renderANSI);

/// Render QR Codes to SVG strings.
Generater<String> createGeneraterSVG(
  Uint8List data, {
  SvgGeneraterOptions options = const SvgGeneraterOptions(),
}) => createGeneraterWithRender(data, options, _renderSVG);

String _payload(EncodedBlock block, GeneraterBaseOptions options) =>
    addUrlPrefix(options.urlPrefix, blockToBase64(block));

QrCodeGenerateResult _renderQRCodeArray(
  EncodedBlock block,
  QrArrayGeneraterOptions options,
) => encode(_payload(block, options), options: options);

String _renderUnicode(EncodedBlock block, UnicodeGeneraterOptions options) =>
    renderUnicode(_payload(block, options), options: options);

String _renderUnicodeCompact(
  EncodedBlock block,
  UnicodeCompactGeneraterOptions options,
) => renderUnicodeCompact(_payload(block, options), options: options);

String _renderANSI(EncodedBlock block, AnsiGeneraterOptions options) =>
    renderANSI(_payload(block, options), options: options);

String _renderSVG(EncodedBlock block, SvgGeneraterOptions options) =>
    renderSVG(_payload(block, options), options: options);
