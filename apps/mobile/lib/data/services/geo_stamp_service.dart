import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Bakes a "GPS Map Camera"-style evidence stamp into a photo: an overlay with
/// the place, coordinates, timestamp and a QR code that opens the exact spot in
/// Google Maps. Baking it into the pixels makes the evidence self-describing and
/// tamper-evident wherever the image is later viewed (admin web, downloaded, …),
/// and instantly distinguishes a live camera capture from a gallery upload.
class GeoStampService {
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static String _fmt(DateTime d) {
    final wd = _weekdays[(d.weekday - 1) % 7];
    final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$wd, ${d.month}/${d.day}/${d.year}  $hh:$mm $ap';
  }

  /// Returns PNG bytes of [imageBytes] with the stamp composited at the bottom,
  /// or null on any failure (caller should fall back to the original photo).
  static Future<Uint8List?> stamp({
    required Uint8List imageBytes,
    required double lat,
    required double lng,
    required String placeLine,
    required DateTime takenAt,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final src = frame.image;
      final w = src.width.toDouble();
      final h = src.height.toDouble();
      if (w < 2 || h < 2) return null;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
      canvas.drawImage(src, Offset.zero, Paint());

      final scale = w / 1000.0; // design tuned for a 1000px-wide image
      final pad = 18 * scale;
      final qrSize = 150 * scale;
      final bannerH = qrSize + pad * 2;
      final bannerTop = h - bannerH;

      canvas.drawRect(Rect.fromLTWH(0, bannerTop, w, bannerH),
          Paint()..color = const Color(0xD9000000));
      canvas.drawRect(Rect.fromLTWH(0, bannerTop, 7 * scale, bannerH),
          Paint()..color = const Color(0xFFC62828));

      // QR (right) — opens the coordinates in Google Maps.
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final qrImg = await QrPainter(
        data: mapsUrl,
        version: QrVersions.auto,
        gapless: true,
      ).toImage(qrSize);
      final qrLeft = w - qrSize - pad;
      final qrTop = bannerTop + pad;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(qrLeft - 5 * scale, qrTop - 5 * scale,
              qrSize + 10 * scale, qrSize + 10 * scale),
          Radius.circular(6 * scale),
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawImageRect(
        qrImg,
        Rect.fromLTWH(0, 0, qrImg.width.toDouble(), qrImg.height.toDouble()),
        Rect.fromLTWH(qrLeft, qrTop, qrSize, qrSize),
        Paint(),
      );

      // Text block (left of the QR).
      final textLeft = pad + 10 * scale;
      final textWidth = qrLeft - textLeft - pad;
      final base = 27 * scale;
      double y = bannerTop + pad;

      void line(String s, double size,
          {FontWeight weight = FontWeight.normal,
          Color color = Colors.white,
          int maxLines = 1}) {
        final tp = TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
                color: color,
                fontSize: size,
                fontWeight: weight,
                height: 1.15),
          ),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          ellipsis: '…',
        )..layout(maxWidth: textWidth);
        tp.paint(canvas, Offset(textLeft, y));
        y += tp.height + 4 * scale;
      }

      line('One Vizcaya  ·  CAMERA CAPTURE', base * 0.82,
          weight: FontWeight.bold, color: const Color(0xFFFF8A80));
      line(placeLine, base, weight: FontWeight.bold, maxLines: 2);
      line('Lat ${lat.toStringAsFixed(6)}°   Long ${lng.toStringAsFixed(6)}°',
          base * 0.82, color: const Color(0xFFEEEEEE));
      line(_fmt(takenAt), base * 0.82, color: const Color(0xFFBDBDBD));

      final out = await recorder.endRecording().toImage(w.toInt(), h.toInt());
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      src.dispose();
      qrImg.dispose();
      out.dispose();
      return png?.buffer.asUint8List();
    } catch (e) {
      debugPrint('GeoStamp failed (using original photo): $e');
      return null;
    }
  }
}
