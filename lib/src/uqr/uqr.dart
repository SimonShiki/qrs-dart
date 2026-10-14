/// `uqr`-compatible QR Code generation and rendering.
///
/// A Dart port of [uqr](https://github.com/unjs/uqr) 0.1.2 (MIT, Anthony Fu),
/// itself a TypeScript port of Project Nayuki's QR Code generator. The public
/// API mirrors upstream's `encode`/`render*` functions.
library;

export 'qr_encode.dart' show encode;
export 'qr_options.dart'
    show
        QrCodeGenerateOptions,
        QrCodeGenerateResult,
        QrCodeGenerateSvgOptions,
        QrCodeGenerateUnicodeOptions;
export 'qr_render.dart'
    show renderANSI, renderSVG, renderUnicode, renderUnicodeCompact;
export 'qr_tables.dart' show QrCodeDataType, QrCodeEcc;
