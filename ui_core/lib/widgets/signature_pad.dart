import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A reusable signature capture widget with drawing canvas.
///
/// Captures freehand drawing and can export the result as PNG bytes.
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    this.width,
    this.height = 200,
    this.penColor = Colors.black,
    this.penWidth = 2.0,
    this.backgroundColor = Colors.white,
    this.onChanged,
  });

  final double? width;
  final double height;
  final Color penColor;
  final double penWidth;
  final Color backgroundColor;

  /// Called whenever the signature changes (stroke added or cleared).
  final ValueChanged<bool>? onChanged;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  bool get isEmpty => _strokes.isEmpty;
  bool get isNotEmpty => _strokes.isNotEmpty;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
    widget.onChanged?.call(false);
  }

  /// Exports the drawn signature as PNG bytes. Returns null if empty.
  Future<Uint8List?> toPngBytes() async {
    if (_strokes.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(
      widget.width ?? context.size?.width ?? 300,
      widget.height,
    );

    // Draw background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = widget.backgroundColor,
    );

    // Draw strokes
    final paint = Paint()
      ..color = widget.penColor
      ..strokeWidth = widget.penWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _currentStroke = [details.localPosition];
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _currentStroke.add(details.localPosition);
                });
              },
              onPanEnd: (_) {
                setState(() {
                  if (_currentStroke.isNotEmpty) {
                    _strokes.add(List.from(_currentStroke));
                    _currentStroke = [];
                    widget.onChanged?.call(true);
                  }
                });
              },
              child: CustomPaint(
                painter: _SignaturePainter(
                  strokes: _strokes,
                  currentStroke: _currentStroke,
                  penColor: widget.penColor,
                  penWidth: widget.penWidth,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _strokes.isEmpty ? null : clear,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Clear'),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.penColor,
    required this.penWidth,
  });

  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color penColor;
  final double penWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = penColor
      ..strokeWidth = penWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> stroke) {
      if (stroke.length < 2) return;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    drawStroke(currentStroke);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
