import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/putt_result.dart';

class PuttDispersionChart extends StatelessWidget {
  const PuttDispersionChart({super.key, required this.results});

  final List<PuttResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Text('No dispersion data yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Legend(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.all(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: PuttDispersionPainter(results),
            ),
          ),
        ),
      ],
    );
  }
}

class PuttDispersionPainter extends CustomPainter {
  PuttDispersionPainter(this.results);

  final List<PuttResult> results;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRadius = size.shortestSide / 2 * 0.8;
    final center = Offset(size.width / 2, size.height / 2);
    const maxFeet = 50.0;
    final scale = outerRadius / maxFeet;

    final backgroundPaint = Paint()..color = const Color(0xFFE6F2E1);
    canvas.drawCircle(center, outerRadius, backgroundPaint);

    final outerRingPaint = Paint()
      ..color = Colors.green.shade800
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, scale * 30, outerRingPaint);

    final dashedPaint15 = Paint()
      ..color = Colors.green.shade500
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    _drawDashedCircle(canvas, center, scale * 15, dashedPaint15);

    final outerMostPaint = Paint()
      ..color = Colors.green.shade900
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, outerRadius, outerMostPaint);

    // Hole marker
    canvas.drawCircle(center, 6, Paint()..color = Colors.black87);

    for (final result in results) {
      final dx = result.x * scale;
      final dy = -result.y * scale;
      final point = center + Offset(dx, dy);

      switch (result.putts) {
        case 1:
          canvas.drawCircle(
            point,
            6,
            Paint()..color = Colors.green.shade900,
          );
          break;
        case 2:
          final paint = Paint()
            ..color = Colors.red.shade600
            ..strokeWidth = 2;
          canvas.drawLine(point + const Offset(-6, -6), point + const Offset(6, 6), paint);
          canvas.drawLine(point + const Offset(-6, 6), point + const Offset(6, -6), paint);
          break;
        default:
          final border = Paint()
            ..color = Colors.red.shade600
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(point, 8, border);
          final textPainter = TextPainter(
            text: TextSpan(
              text: '3',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            point - Offset(textPainter.width / 2, textPainter.height / 2),
          );
          break;
      }
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dashLength = 10;
    const gapLength = 6;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (dashLength + gapLength) / radius;
      final endAngle = startAngle + dashLength / radius;

      final start = Offset(
        center.dx + radius * math.cos(startAngle),
        center.dy + radius * math.sin(startAngle),
      );
      final end = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PuttDispersionPainter oldDelegate) =>
      oldDelegate.results != results;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: const [
        _LegendItem(
          label: '1 Putt',
          type: _LegendMarker.circle,
        ),
        _LegendItem(
          label: '2 Putts',
          type: _LegendMarker.cross,
        ),
        _LegendItem(
          label: '3 Putts',
          type: _LegendMarker.number,
        ),
      ],
    );
  }
}

enum _LegendMarker { circle, cross, number }

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.type});

  final String label;
  final _LegendMarker type;

  @override
  Widget build(BuildContext context) {
    Widget marker;
    switch (type) {
      case _LegendMarker.circle:
        marker = Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        );
        break;
      case _LegendMarker.cross:
        marker = SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(
            painter: _CrossPainter(),
          ),
        );
        break;
      case _LegendMarker.number:
        marker = Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.shade600, width: 2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '3',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.shade600
      ..strokeWidth = 2;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) => false;
}
