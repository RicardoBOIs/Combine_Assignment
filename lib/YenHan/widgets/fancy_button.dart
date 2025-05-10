import 'package:flutter/material.dart';

class FancyButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;

  const FancyButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.color = const Color(0xFF4CAF50), // Default to primary green
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          width: double.infinity,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}