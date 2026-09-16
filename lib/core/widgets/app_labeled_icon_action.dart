import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLabeledIconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool compact;

  const AppLabeledIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: SizedBox.square(
            dimension: compact ? 34 : AppSize.minTouchTarget,
            child: Center(
              child: Material(
                color: color.withValues(alpha: .1),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: SizedBox.square(
                    dimension: compact ? 34 : 38,
                    child: Icon(icon, size: compact ? 16 : 18, color: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
