import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final bool enabled;  // Added for controlling enabled state
  final bool outlined; // Added for outlined style
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final double borderRadius;
  final double elevation;

  const CustomButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.enabled = true, // defaults to true
    this.outlined = false, // defaults to false (filled button)
    this.color,
    this.textColor,
    this.icon,
    this.borderRadius = 14,
    this.elevation = 1.5,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDisabled = isDisabled || !enabled;

    final backgroundColor = outlined
        ? Colors.transparent
        : (effectiveDisabled ? Colors.grey[300] : color ?? Colors.blue);

    final foregroundColor = effectiveDisabled
        ? Colors.grey[600]
        : textColor ?? (outlined ? Colors.blue : Colors.white);

    final borderSide = outlined
        ? BorderSide(
      color: effectiveDisabled ? Colors.grey[300]! : (color ?? Colors.blue),
      width: 2,
    )
        : BorderSide.none;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (isLoading || effectiveDisabled) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: outlined ? 0 : elevation,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foregroundColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
