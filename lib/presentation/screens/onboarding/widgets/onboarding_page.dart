import 'package:flutter/material.dart';

/// Data model for onboarding page content
class OnboardingPageData {
  final String titleLine1;
  final String titleLine2;
  final String subtitle;
  final String assetPath;

  const OnboardingPageData({
    required this.titleLine1,
    required this.titleLine2,
    required this.subtitle,
    required this.assetPath,
  });
}

/// Reusable onboarding page widget with title (two-line with gradient),
/// subtitle, and decorative wave background.
class OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final bool isLastPage;

  const OnboardingPage({
    super.key,
    required this.data,
    this.isLastPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Column(
      children: [
        // ── Title & subtitle ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Two-line title: first line dark navy, second line blue gradient
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                  children: [
                    TextSpan(
                      text: '${data.titleLine1}\n',
                      style: const TextStyle(color: Color(0xFF0D1B3E)),
                    ),
                    TextSpan(
                      text: data.titleLine2,
                      style: TextStyle(
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          ).createShader(
                            // Responsive gradient rect based on text width
                            Rect.fromLTWH(0, 0, screenSize.width * 0.7, 40),
                          ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF546E8A),
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        // ── Illustration ────────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              // Blue wave background at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: const _WaveBackground(),
              ),
              // Main illustration with error handling
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Image.asset(
                    data.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback UI if asset fails to load
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 80,
                          color: Color(0xFF90CAF9),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Decorative wave-shaped background at the bottom of each page.
class _WaveBackground extends StatelessWidget {
  const _WaveBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _WavePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Custom painter for animated wave background
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD6EAFF), Color(0xFFEAF4FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.45)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.1,
        size.width * 0.75,
        size.height * 0.8,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}