import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String message;

  const EmptyStateWidget({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 16,
        ),
      ),
    );
  }
}
