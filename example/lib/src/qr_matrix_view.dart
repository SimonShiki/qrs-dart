import 'package:material_ui/material_ui.dart';

/// Draws a QR module matrix as crisp, integer-sized squares.
///
/// The stream is generated for a camera, so the modules must not be
/// anti-aliased and the quiet zone must stay white.
class QrMatrixView extends StatelessWidget {
  /// Creates a view for [matrix] (`true` = dark module).
  const QrMatrixView({
    super.key,
    required this.matrix,
    this.quietZone = 4,
    this.foreground = Colors.black,
    this.background = Colors.white,
  });

  /// Square module matrix, row-major.
  final List<List<bool>> matrix;

  /// Quiet zone in modules around the code.
  final int quietZone;

  /// Colour of a dark module.
  final Color foreground;

  /// Colour of the background and quiet zone.
  final Color background;

  @override
  Widget build(BuildContext context) {
    if (matrix.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = matrix.length + quietZone * 2;
        final available = constraints.biggest.shortestSide;
        final moduleSize = available.isFinite && available > 0
            ? (available / total).floorToDouble().clamp(1.0, 64.0)
            : 1.0;
        final size = moduleSize * total;

        final canvas = SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _QrMatrixPainter(
              matrix: matrix,
              moduleSize: moduleSize,
              quietZone: quietZone,
              foreground: foreground,
              background: background,
            ),
          ),
        );

        // Only shrink when the parent cannot fit one pixel per module.
        return available.isFinite && size > available
            ? FittedBox(fit: BoxFit.contain, child: canvas)
            : Center(child: canvas);
      },
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  const _QrMatrixPainter({
    required this.matrix,
    required this.moduleSize,
    required this.quietZone,
    required this.foreground,
    required this.background,
  });

  final List<List<bool>> matrix;
  final double moduleSize;
  final int quietZone;
  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final paint = Paint()
      ..color = foreground
      ..isAntiAlias = false;
    final offset = quietZone * moduleSize;

    for (var y = 0; y < matrix.length; y++) {
      final row = matrix[y];
      for (var x = 0; x < row.length; x++) {
        if (!row[x]) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            offset + x * moduleSize,
            offset + y * moduleSize,
            moduleSize,
            moduleSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrMatrixPainter oldDelegate) =>
      oldDelegate.matrix != matrix ||
      oldDelegate.moduleSize != moduleSize ||
      oldDelegate.foreground != foreground ||
      oldDelegate.background != background;
}
