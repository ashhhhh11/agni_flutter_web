import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Pin Data ─────────────────────────────────────────────────────────────────

class GlobePin {
  final String name;
  final double lat;
  final double lon;
  final Color color;
  const GlobePin({
    required this.name,
    required this.lat,
    required this.lon,
    required this.color,
  });
}

const List<GlobePin> globePins = [
  GlobePin(name: 'USA',   lat: 39,   lon: -98,  color: Color(0xFF60A5FA)),
  GlobePin(name: 'UK',    lat: 52,   lon: -1,   color: Color(0xFFC084FC)),
  GlobePin(name: 'Dubai', lat: 25.2, lon: 55.3, color: Color(0xFFFBBF24)),
  GlobePin(name: 'India', lat: 22,   lon: 80,   color: Color(0xFF34D399)),
];

// ─── Continent Polygon Data ───────────────────────────────────────────────────
// Each entry is a list of [lon, lat] pairs forming a closed polygon.

final List<List<List<double>>> continentPolygons = [
  // North America
  [[-168,71],[-140,70],[-125,49],[-123,37],[-117,32],[-97,26],[-90,29],[-84,30],[-80,25],[-80,43],[-75,45],[-67,47],[-53,47],[-60,46],[-65,44],[-70,43],[-74,41],[-76,35],[-80,32],[-82,30],[-90,29.5],[-97,25.8],[-105,20],[-115,32],[-120,34],[-122,37],[-124,47],[-130,54],[-140,59],[-145,61],[-155,59],[-160,55],[-165,62],[-168,65]],
  // South America
  [[-80,9],[-76,8],[-72,0],[-70,-5],[-75,-10],[-80,-6],[-81,-2],[-80,-15],[-75,-20],[-70,-30],[-65,-35],[-65,-40],[-68,-53],[-65,-55],[-60,-52],[-53,-33],[-48,-28],[-43,-23],[-38,-13],[-35,-6],[-35,0],[-38,5],[-45,5],[-50,5],[-55,5],[-60,8],[-68,10],[-75,10],[-78,8]],
  // Europe
  [[-10,36],[-8,44],[-9,39],[-9,44],[-5,44],[-2,43],[3,43],[5,44],[8,44],[10,54],[12,55],[15,57],[18,60],[20,63],[25,65],[28,70],[30,68],[28,60],[25,55],[22,51],[18,48],[15,44],[12,44],[8,44],[5,44],[3,52],[2,51],[0,51],[-2,52],[-5,50]],
  // Africa
  [[-18,15],[-16,12],[-15,5],[-8,4],[-5,5],[0,5],[5,4],[10,5],[15,4],[22,5],[32,4],[40,10],[42,12],[43,15],[42,22],[40,28],[38,30],[36,32],[30,30],[25,30],[22,32],[20,35],[15,37],[10,37],[5,37],[0,35],[-5,35],[-12,30],[-17,25],[-18,20],[-18,15]],
  // Middle East / Arabian Peninsula
  [[28,42],[32,36],[36,32],[38,30],[40,28],[42,22],[43,15],[42,12],[50,12],[60,24],[68,22],[72,20],[75,18],[78,14],[80,10],[80,12],[72,34],[68,36],[60,30],[55,26],[50,28],[45,42],[40,42],[35,38]],
  // Asia (main body)
  [[40,42],[45,42],[50,46],[55,50],[60,56],[65,52],[70,50],[75,52],[80,55],[85,55],[90,53],[95,55],[100,52],[105,50],[110,48],[115,44],[120,42],[125,40],[130,38],[132,34],[130,32],[125,32],[120,28],[115,26],[110,22],[105,18],[100,12],[98,5],[103,-1],[108,-7],[115,-2],[120,5],[125,10],[130,12],[135,8],[138,10],[142,12],[145,15],[145,40],[142,45],[138,50],[132,48],[128,48],[125,50],[120,52],[115,55],[110,55],[105,52],[100,50],[95,50],[90,52],[85,50],[80,50],[75,55],[70,58],[65,60],[60,60],[55,58],[50,55],[45,50]],
  // Australia
  [[115,-22],[118,-20],[122,-18],[128,-15],[136,-12],[138,-15],[140,-18],[142,-22],[147,-38],[149,-40],[151,-36],[153,-28],[150,-24],[145,-18],[140,-15],[136,-12],[130,-15],[122,-20],[115,-22]],
  // UK
  [[-5,50],[-3,50],[0,51],[2,51],[1,53],[-2,54],[-5,56],[-6,58],[-5,58],[-3,56],[-1,55],[-3,52],[-5,51]],
  // Greenland
  [[-25,63],[-18,63],[-13,65],[-13,67],[-18,68],[-22,68],[-24,66]],
  // Japan
  [[130,31],[132,33],[135,35],[138,37],[140,40],[141,42],[140,44],[138,44],[136,42],[134,38],[131,34],[130,32]],
  // Scandinavia
  [[8,56],[10,56],[12,55],[15,57],[18,60],[20,63],[25,65],[28,68],[26,70],[22,70],[18,70],[15,68],[12,65],[8,62],[6,58],[8,56]],
];

// ─── Earth Globe Painter ──────────────────────────────────────────────────────

class EarthGlobePainter extends CustomPainter {
  final double t;      // 0.0 → 1.0 from AnimationController (use repeat())
  final bool isDark;

  EarthGlobePainter({required this.t, required this.isDark});

  // Convert lat/lon (degrees) → unit sphere XYZ
  static List<double> _latLonToXYZ(double lat, double lon) {
    final phi = (90 - lat) * math.pi / 180;
    final theta = lon * math.pi / 180;
    return [
      math.sin(phi) * math.cos(theta),
      math.cos(phi),
      math.sin(phi) * math.sin(theta),
    ];
  }

  // Project XYZ with horizontal rotation angle → canvas coords
  // Returns (screenX, screenY, rz) — rz < 0 means back-facing
  static Map<String, double> _project(
      List<double> xyz, double angle, double cx, double cy, double R) {
    final ca = math.cos(angle), sa = math.sin(angle);
    final rx = xyz[0] * ca - xyz[2] * sa;
    final rz = xyz[0] * sa + xyz[2] * ca;
    return {'sx': cx + rx * R, 'sy': cy - xyz[1] * R, 'rz': rz};
  }

  @override
  void paint(Canvas canvas, Size size) {
    final R = size.width * 0.46;
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Full rotation: t goes 0→1, so angle goes 0→2π
    final angle = t * 2 * math.pi;

    // ── Ocean background ──────────────────────────────────────────────────────
    final oceanPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: const [Color(0xFF1A4A7A), Color(0xFF0D2D52), Color(0xFF071828)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: R));

    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: R));
    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawCircle(Offset(cx, cy), R, oceanPaint);

    // ── Grid lines ────────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFF64B4FF).withOpacity(0.10)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (double lat = -60; lat <= 60; lat += 20) {
      final path = Path();
      bool first = true;
      for (double lon = -180; lon <= 180; lon += 3) {
        final v = _latLonToXYZ(lat, lon);
        final p = _project(v, angle, cx, cy, R);
        if (p['rz']! < 0) { first = true; continue; }
        if (first) { path.moveTo(p['sx']!, p['sy']!); first = false; }
        else { path.lineTo(p['sx']!, p['sy']!); }
      }
      canvas.drawPath(path, gridPaint);
    }
    for (double lon = -180; lon < 180; lon += 20) {
      final path = Path();
      bool first = true;
      for (double lat = -85; lat <= 85; lat += 3) {
        final v = _latLonToXYZ(lat, lon);
        final p = _project(v, angle, cx, cy, R);
        if (p['rz']! < 0) { first = true; continue; }
        if (first) { path.moveTo(p['sx']!, p['sy']!); first = false; }
        else { path.lineTo(p['sx']!, p['sy']!); }
      }
      canvas.drawPath(path, gridPaint);
    }

    // ── Continents ────────────────────────────────────────────────────────────
    final landFill = Paint()
      ..color = const Color(0xFF2A7A48)
      ..style = PaintingStyle.fill;
    final landStroke = Paint()
      ..color = const Color(0xFF78DCA0).withOpacity(0.55)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final polygon in continentPolygons) {
      final path = Path();
      bool first = true;
      bool anyVisible = false;

      for (final lonLat in polygon) {
        final lon = lonLat[0], lat = lonLat[1];
        final v = _latLonToXYZ(lat, lon);
        final p = _project(v, angle, cx, cy, R);
        if (p['rz']! < -0.05) { first = true; continue; }
        anyVisible = true;
        if (first) { path.moveTo(p['sx']!, p['sy']!); first = false; }
        else { path.lineTo(p['sx']!, p['sy']!); }
      }

      if (anyVisible) {
        path.close();
        canvas.drawPath(path, landFill);
        canvas.drawPath(path, landStroke);
      }
    }

    // ── Specular shine ────────────────────────────────────────────────────────
    final shinePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        radius: 0.8,
        colors: [
          Colors.white.withOpacity(0.10),
          Colors.white.withOpacity(0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: R));
    canvas.drawCircle(Offset(cx, cy), R, shinePaint);

    canvas.restore();

    // ── Globe rim ─────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy), R,
      Paint()
        ..color = const Color(0xFF64B4FF).withOpacity(0.30)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // ── Atmosphere glow ───────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy), R + 14,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [
            Colors.transparent,
            const Color(0xFF50A0FF).withOpacity(0.00),
            const Color(0xFF50A0FF).withOpacity(0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.88, 0.94, 1.0],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: R + 14)),
    );

    // ── Pins ──────────────────────────────────────────────────────────────────
    for (final pin in globePins) {
      final v = _latLonToXYZ(pin.lat, pin.lon);
      final p = _project(v, angle, cx, cy, R);
      if (p['rz']! < 0.08) continue;

      final alpha = ((p['rz']! - 0.08) / 0.25).clamp(0.0, 1.0);
      final sx = p['sx']!;
      final sy = p['sy']!;
      const stemH = 22.0;
      const dotR = 6.0;

      // Stem
      canvas.drawLine(
        Offset(sx, sy),
        Offset(sx, sy - stemH),
        Paint()
          ..color = pin.color.withOpacity(alpha * 0.95)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );

      // Pulse ring
      canvas.drawCircle(
        Offset(sx, sy - stemH - dotR),
        dotR + 5,
        Paint()
          ..color = pin.color.withOpacity(alpha * 0.25)
          ..style = PaintingStyle.fill,
      );

      // Dot fill
      canvas.drawCircle(
        Offset(sx, sy - stemH - dotR),
        dotR,
        Paint()
          ..color = pin.color.withOpacity(alpha)
          ..style = PaintingStyle.fill,
      );

      // Dot border
      canvas.drawCircle(
        Offset(sx, sy - stemH - dotR),
        dotR,
        Paint()
          ..color = Colors.white.withOpacity(alpha * 0.75)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: pin.name,
          style: TextStyle(
            color: Colors.white.withOpacity(alpha),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.80),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(sx - tp.width / 2, sy - stemH - dotR * 2 - tp.height - 4),
      );
    }

    // ── Shadow under globe ────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + R + 10),
        width: R * 1.6,
        height: R * 0.18,
      ),
      Paint()
        ..color = const Color(0xFF0A2342).withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(EarthGlobePainter old) =>
      old.t != t || old.isDark != isDark;
}

// ─── Usage example ────────────────────────────────────────────────────────────
//
// In your widget (with TickerProviderStateMixin):
//
//   late AnimationController _globeController;
//
//   @override
//   void initState() {
//     super.initState();
//     _globeController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 12),
//     )..repeat();  // <-- use repeat() NOT repeat(reverse: true)
//   }
//
//   // In build():
//   AnimatedBuilder(
//     animation: _globeController,
//     builder: (_, __) => CustomPaint(
//       size: const Size(360, 360),
//       painter: EarthGlobePainter(
//         t: _globeController.value,
//         isDark: isDark,
//       ),
//     ),
//   )