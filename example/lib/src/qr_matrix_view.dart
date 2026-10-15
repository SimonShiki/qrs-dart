import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Draws a QR module matrix as crisp, integer-sized squares.
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
              modules: _buildModuleVertices(
                matrix,
                moduleSize,
                quietZone * moduleSize,
              ),
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

/// Packs every horizontal run of dark modules into one quad (two triangles),
/// so the whole code becomes one [ui.Vertices] buffer.
///
/// Coordinates are `offset + n * moduleSize`, and the caller guarantees integer
/// logical pixels for both, so module edges land exactly on pixel boundaries
/// and stay crisp. Returns `null` for an all-white matrix, which needs no
/// vertex draw at all.
ui.Vertices? _buildModuleVertices(
  List<List<bool>> matrix,
  double moduleSize,
  double offset,
) {
  // Count the dark runs first so the buffer can be allocated exactly once:
  // no growth, no per-frame garbage beyond the buffer itself.
  var runs = 0;
  for (final row in matrix) {
    for (var x = 0; x < row.length;) {
      if (!row[x]) {
        x += 1;
        continue;
      }
      runs += 1;
      while (x < row.length && row[x]) {
        x += 1;
      }
    }
  }
  if (runs == 0) return null;

  // Six vertices (two triangles) per run, two floats per vertex.
  final positions = Float32List(runs * 12);
  var i = 0;
  for (var y = 0; y < matrix.length; y++) {
    final row = matrix[y];
    final top = offset + y * moduleSize;
    final bottom = top + moduleSize;

    for (var x = 0; x < row.length;) {
      if (!row[x]) {
        x += 1;
        continue;
      }
      var end = x + 1;
      while (end < row.length && row[end]) {
        end += 1;
      }

      final left = offset + x * moduleSize;
      final right = offset + end * moduleSize;

      // Top-left, top-right, bottom-right / top-left, bottom-right, bottom-left.
      positions[i++] = left;
      positions[i++] = top;
      positions[i++] = right;
      positions[i++] = top;
      positions[i++] = right;
      positions[i++] = bottom;

      positions[i++] = left;
      positions[i++] = top;
      positions[i++] = right;
      positions[i++] = bottom;
      positions[i++] = left;
      positions[i++] = bottom;

      x = end;
    }
  }

  return ui.Vertices.raw(ui.VertexMode.triangles, positions);
}

class _QrMatrixPainter extends CustomPainter {
  const _QrMatrixPainter({
    required this.matrix,
    required this.modules,
    required this.foreground,
    required this.background,
  });

  final List<List<bool>> matrix;

  /// The dark modules as one vertex buffer, or `null` when there are none.
  final ui.Vertices? modules;

  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final modules = this.modules;
    if (modules == null) return;

    // `Paint.color` is the colour of the triangles when the vertices carry no
    // per-vertex colours; without those the blend mode is unused as well.
    canvas.drawVertices(
      modules,
      ui.BlendMode.srcOver,
      Paint()
        ..color = foreground
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_QrMatrixPainter oldDelegate) =>
      oldDelegate.matrix != matrix ||
      oldDelegate.foreground != foreground ||
      oldDelegate.background != background;
}
