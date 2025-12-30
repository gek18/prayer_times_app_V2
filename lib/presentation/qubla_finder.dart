import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class QiblaFinder extends StatefulWidget {
  const QiblaFinder({super.key});

  @override
  State<QiblaFinder> createState() => _QiblaFinderState();
}

class _QiblaFinderState extends State<QiblaFinder>
    with TickerProviderStateMixin {
  StreamSubscription<QiblahDirection>? _subscription;
  bool _locationGranted = false;
  bool _sensorSupported = true;
  bool _streamReady = false;

  double _angle = 0;
  double _smoothedAngle = 0;
  final List<double> _window = [];

  static const double _alpha = 0.15;
  static const int _medianWindowSize = 7;
  static const double toleranceDeg = 3;

  late AnimationController _rotateCtrl;
  late Animation<double> _rotationAnim;
  double _prevRad = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  bool _alignedPreviously = false;

  @override
  void initState() {
    super.initState();

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _pulseOpacity = Tween<double>(
      begin: 0.25,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initialize();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.locationWhenInUse.request();
    setState(() => _locationGranted = status.isGranted);
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    if (!_locationGranted) {
      setState(() {});
      return;
    }

    if (Theme.of(context).platform == TargetPlatform.android) {
      final supported = await FlutterQiblah.androidDeviceSensorSupport();
      _sensorSupported = supported ?? true;
    } else {
      _sensorSupported = true;
    }

    if (_sensorSupported) {
      _listenQiblah();
    } else {
      setState(() {});
    }
  }

  void _listenQiblah() {
    _subscription?.cancel();

    _subscription = FlutterQiblah.qiblahStream.listen((q) {
      double raw = (q.qiblah % 360 + 360) % 360;

      if (raw.isNaN) return;

      _smoothedAngle = _smoothedAngle == 0
          ? raw
          : _smoothedAngle + _alpha * (raw - _smoothedAngle);

      _window.add(_smoothedAngle);
      if (_window.length > _medianWindowSize) _window.removeAt(0);
      final sorted = [..._window]..sort();
      _angle = sorted[sorted.length ~/ 2];

      _animateNeedle();

      if (!_streamReady) setState(() => _streamReady = true);

      final aligned = _isAligned(_angle, toleranceDeg);

      if (aligned && !_alignedPreviously) {
        HapticFeedback.mediumImpact();
      }

      _alignedPreviously = aligned;
    });
  }

  void _animateNeedle() {
    final targetRad = -_angle * pi / 180;

    _rotationAnim = Tween<double>(
      begin: _prevRad,
      end: targetRad,
    ).animate(CurvedAnimation(parent: _rotateCtrl, curve: Curves.easeOut));

    _rotateCtrl.forward(from: 0);
    _prevRad = targetRad;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.tajawal(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('اتجاه القبلة', style: style),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_locationGranted) {
      return _buildHint(
        'يرجى تفعيل صلاحية الموقع لتحديد اتجاه القبلة',
        onRetry: _initialize,
      );
    }
    if (!_sensorSupported) {
      return _buildHint('هذا الجهاز لا يدعم مستشعرات البوصلة المطلوبة.');
    }
    if (!_streamReady) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      );
    }
    return _buildCompassUI();
  }

  Widget _buildHint(String text, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 72),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent.withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'إعادة المحاولة',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassUI() {
    final size = MediaQuery.of(context).size;
    final compassSize = min(size.width * 0.78, 330.0);

    final aligned = _isAligned(_angle, toleranceDeg);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: AnimatedBuilder(
            animation: _rotateCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _rotationAnim.value,
              alignment: Alignment.center,
              child: child,
            ),
            child: Container(
              width: compassSize,
              height: compassSize,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(compassSize, compassSize),
                    painter: _DialPainter(),
                  ),
                  Icon(
                    Icons.navigation_rounded,
                    size: compassSize * 0.45,
                    color: Colors.tealAccent,
                  ),
                  if (aligned)
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseScale.value,
                        child: Opacity(
                          opacity: _pulseOpacity.value,
                          child: Container(
                            width: compassSize * 0.18,
                            height: compassSize * 0.18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.tealAccent.withOpacity(0.8),
                                  Colors.tealAccent.withOpacity(0.1),
                                ],
                                stops: const [0.3, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.tealAccent.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          aligned
              ? 'تم الضبط بدقة — هذا هو اتجاه القبلة'
              : 'اتجه نحو السهم لتكون متجهاً للقبلة',
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          aligned
              ? 'ثبّت الهاتف لثوانٍ... الدقّة ممتازة ✅'
              : 'حرّك الهاتف بشكل 8 لتحسين دقة البوصلة',
          style: GoogleFonts.tajawal(
            color: aligned ? Colors.greenAccent : Colors.white70,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  bool _isAligned(double deg, double tolerance) {
    final d = (deg % 360 + 360) % 360;
    return d <= tolerance || (360 - d) <= tolerance;
  }
}

class _DialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const LinearGradient(
        colors: [Colors.tealAccent, Colors.cyanAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, ringPaint);

    final tickPaint = Paint()
      ..strokeWidth = 1
      ..color = Colors.white24;

    const ticks = 36;

    for (int i = 0; i < ticks; i++) {
      final a = 2 * pi * i / ticks;
      final p1 = Offset(
        center.dx + (radius - 6) * cos(a),
        center.dy + (radius - 6) * sin(a),
      );
      final p2 = Offset(
        center.dx + radius * cos(a),
        center.dy + radius * sin(a),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    final textStyle = const TextStyle(color: Colors.white70, fontSize: 13);

    _drawText(canvas, size, 'شمال', 0, radius - 20, textStyle);
    _drawText(canvas, size, 'شرق', 90, radius - 20, textStyle);
    _drawText(canvas, size, 'جنوب', 180, radius - 20, textStyle);
    _drawText(canvas, size, 'غرب', 270, radius - 20, textStyle);
  }

  void _drawText(
    Canvas c,
    Size s,
    String text,
    double deg,
    double r,
    TextStyle style,
  ) {
    final center = s.center(Offset.zero);
    final a = deg * pi / 180;

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
    )..layout();

    final pos = Offset(
      center.dx + r * cos(a) - tp.width / 2,
      center.dy + r * sin(a) - tp.height / 2,
    );

    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(_) => false;
}
