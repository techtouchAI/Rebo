import 'package:flutter/material.dart';

/// Small rounded label used for meta information (grade, template, count…).
class MetaPill extends StatelessWidget {
  const MetaPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? tone.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}
