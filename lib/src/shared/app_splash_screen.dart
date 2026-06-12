import 'package:flutter/material.dart';

import 'branding.dart';

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({
    super.key,
    this.status = 'Preparing your wallet',
    this.error,
  });

  final String status;
  final Object? error;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0C121B),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = hasError ? 1.0 : _controller.value;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashBackgroundPainter(progress: value),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MotionLogo(progress: value),
                          const SizedBox(height: 28),
                          Opacity(
                            opacity: _interval(value, 0.18, 0.52),
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                10 * (1 - _interval(value, 0.18, 0.52)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'MyWallet',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    hasError
                                        ? 'Firebase setup needs attention'
                                        : widget.status,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFFB9C4D4),
                                          letterSpacing: 0,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          _AnimatedProgressRail(
                            progress: hasError
                                ? 1
                                : _interval(value, 0.08, 0.92),
                            hasError: hasError,
                          ),
                          if (hasError) ...[
                            const SizedBox(height: 18),
                            Text(
                              '${widget.error}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFFFB4AB)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MotionLogo extends StatelessWidget {
  const _MotionLogo({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final entrance = _interval(progress, 0, 0.42, Curves.easeOutCubic);
    final settle = _interval(progress, 0.06, 0.55, Curves.easeOutBack);
    final shine = _interval(progress, 0.28, 0.78, Curves.easeInOutCubic);
    final border = _interval(progress, 0.1, 0.82, Curves.easeOutCubic);

    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2,
            child: Opacity(
              opacity: 0.38 * entrance,
              child: Container(
                width: 150 + 16 * entrance,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA000000),
                      blurRadius: 38,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, 24 * (1 - entrance)),
            child: Transform.scale(
              scale: 0.84 + (0.16 * settle),
              child: Opacity(
                opacity: entrance,
                child: SizedBox(
                  width: 142,
                  height: 142,
                  child: Stack(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(31),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 34,
                              offset: Offset(0, 20),
                            ),
                            BoxShadow(
                              color: Color(0x44FFC857),
                              blurRadius: 28,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(31),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                walletLogoAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const ColoredBox(
                                    color: Color(0xFF121A27),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      color: Color(0xFFFFC857),
                                      size: 64,
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                left: -90 + (230 * shine),
                                top: -34,
                                bottom: -34,
                                child: Transform.rotate(
                                  angle: -0.35,
                                  child: Container(
                                    width: 42,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Colors.white.withValues(alpha: 0.34),
                                          Colors.white.withValues(alpha: 0),
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
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LogoTracePainter(progress: border),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(bottom: 0, child: _GrowingBars(progress: progress)),
        ],
      ),
    );
  }
}

class _GrowingBars extends StatelessWidget {
  const _GrowingBars({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final heights = [14.0, 23.0, 33.0, 46.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < heights.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.scale(
              alignment: Alignment.bottomCenter,
              scaleY: _interval(
                progress,
                0.34 + index * 0.06,
                0.66 + index * 0.06,
                Curves.easeOutCubic,
              ),
              child: Container(
                width: 9,
                height: heights[index],
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedProgressRail extends StatelessWidget {
  const _AnimatedProgressRail({required this.progress, required this.hasError});

  final double progress;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: ColoredBox(
        color: Colors.white.withValues(alpha: 0.12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.08, 1),
            child: ColoredBox(
              color: hasError
                  ? const Color(0xFFFFB4AB)
                  : const Color(0xFFFFC857),
              child: const SizedBox(height: 4),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoTracePainter extends CustomPainter {
  const _LogoTracePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(31),
    ).deflate(3);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = const Color(0xFFFFD978)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0, 1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoTracePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  const _SplashBackgroundPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF121A27), Color(0xFF070A0F)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final offset = 32 * progress;
    for (var index = -4; index < 12; index++) {
      final y = size.height * 0.18 + index * 52 + offset;
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y - 80),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

double _interval(
  double value,
  double begin,
  double end, [
  Curve curve = Curves.easeOut,
]) {
  return Interval(begin, end, curve: curve).transform(value.clamp(0, 1));
}
