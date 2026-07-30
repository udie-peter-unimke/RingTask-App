import 'package:flutter/material.dart';

/// Enum to explicitly classify permission types for localized triggering.
enum OnboardingPermissionType {
  notifications,
  overlay,
  none,
}

/// Data model for onboarding page content
class OnboardingPageData {
  final String titleLine1;
  final String titleLine2;
  final String subtitle;
  final String assetPath;
  final OnboardingPermissionType permissionType;

  const OnboardingPageData({
    required this.titleLine1,
    required this.titleLine2,
    required this.subtitle,
    required this.assetPath,
    this.permissionType = OnboardingPermissionType.none,
  });
}

/// Reusable onboarding page widget with title (two-line with gradient),
/// subtitle, interactive permission hooks, and decorative wave background.
class OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final bool isLastPage;
  final VoidCallback? onPermissionRequest;
  final bool isPermissionGranted;

  const OnboardingPage({
    super.key,
    required this.data,
    this.isLastPage = false,
    this.onPermissionRequest,
    this.isPermissionGranted = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPermissionPage = data.permissionType != OnboardingPermissionType.none;

    return Column(
      children: [
        // ── Title & Subtitle ───────────────────────────────────────────────
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

        // ── Interactive Action Zone (For System Permissions) ───────────────
        if (isPermissionPage) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isPermissionGranted
                  ? _buildSuccessPill()
                  : _buildActionButton(),
            ),
          ),
        ],

        // ── Illustration & Waves ────────────────────────────────────────────
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
                  padding: EdgeInsets.only(
                    top: isPermissionPage ? 8 : 16,
                    bottom: 8,
                  ),
                  child: Image.asset(
                    data.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 60,
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

  // ── Action Components ─────────────────────────────────────────────

  Widget _buildActionButton() {
    return ElevatedButton.icon(
      key: const ValueKey('grant_button'),
      onPressed: onPermissionRequest,
      icon: const Icon(Icons.security_outlined, size: 18),
      label: const Text(
        'Grant Permissions',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF1565C0),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 1,
      ),
    );
  }

  Widget _buildSuccessPill() {
    return Container(
      key: const ValueKey('granted_pill'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF388E3C), size: 20),
          SizedBox(width: 8),
          Text(
            'Permission Granted',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
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

/// Custom painter for static wave background
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