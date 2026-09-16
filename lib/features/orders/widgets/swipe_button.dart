import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Nút vuốt để xác nhận hành động quan trọng.
class SwipeButton extends StatefulWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onConfirm;

  const SwipeButton({
    super.key,
    required this.label,
    required this.color,
    required this.loading,
    required this.onConfirm,
  });

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton>
    with SingleTickerProviderStateMixin {
  static const double _h = 56.0;
  static const double _thumb = 46.0;
  static const double _pad = 5.0;

  double _dragX = 0;
  bool _triggered = false;

  late AnimationController _ctrl;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d, double max) {
    if (_triggered || widget.loading) return;
    setState(() => _dragX = (_dragX + d.delta.dx).clamp(0, max));
  }

  void _onEnd(DragEndDetails d, double max) {
    if (_triggered || widget.loading) return;
    if (_dragX >= max * 0.82) {
      setState(() {
        _dragX = max;
        _triggered = true;
      });
      widget.onConfirm?.call();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _dragX = 0;
            _triggered = false;
          });
        }
      });
    } else {
      _snapAnim = Tween<double>(begin: _dragX, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      )..addListener(() => setState(() => _dragX = _snapAnim.value));
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _h,
      child: LayoutBuilder(builder: (ctx, box) {
        final max = box.maxWidth - _thumb - _pad * 2;
        final progress = max > 0 ? (_dragX / max).clamp(0.0, 1.0) : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(_h / 2),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: .24),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(children: [
            // Fill progress
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(_h / 2),
                  ),
                ),
              ),
            ),

            // Label
            Center(
              child: Opacity(
                opacity: (1 - progress * 1.6).clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 58),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: Colors.white.withValues(alpha: .72),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Thumb
            Positioned(
              left: _pad + _dragX,
              top: _pad,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => _onUpdate(d, max),
                onHorizontalDragEnd: (d) => _onEnd(d, max),
                child: Container(
                  width: _thumb,
                  height: _thumb,
                  decoration: BoxDecoration(
                    color: widget.loading
                        ? Colors.white.withValues(alpha: .88)
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x29000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: widget.loading
                      ? const Center(
                          child: SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_rounded,
                          color: widget.color,
                          size: 21,
                        ),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}
