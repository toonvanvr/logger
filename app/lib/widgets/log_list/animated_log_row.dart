part of 'log_row.dart';

class _AnimatedLogRow extends StatefulWidget {
  final LogRow parent;
  const _AnimatedLogRow({required this.parent});

  @override
  State<_AnimatedLogRow> createState() => _AnimatedLogRowState();
}

class _AnimatedLogRowState extends State<_AnimatedLogRow>
    with SingleTickerProviderStateMixin, _LogRowInteraction<_AnimatedLogRow> {
  @override
  LogRow get _row => widget.parent;
  late final AnimationController _controller;
  late final Animation<Color?> _highlightAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.075, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<double>(begin: 4, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.075, curve: Curves.easeOut),
      ),
    );
    const hl = LoggerColors.highlight;
    _highlightAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.transparent, end: hl),
        weight: 150,
      ),
      TweenSequenceItem(tween: ConstantTween<Color?>(hl), weight: 200),
      TweenSequenceItem(
        tween: ColorTween(begin: hl, end: Colors.transparent),
        weight: 1650,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: buildTapHandler(
              child: ValueListenableBuilder<bool>(
                valueListenable: hoverNotifier,
                builder: (context, isHovered, innerChild) {
                  return Container(
                    constraints: const BoxConstraints(minHeight: 24),
                    decoration: BoxDecoration(
                      color: computeBackground(isHovered),
                      border: Border(
                        bottom: BorderSide(
                          color: LoggerColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    foregroundDecoration:
                        _highlightAnimation.value != null &&
                            _highlightAnimation.value != Colors.transparent
                        ? BoxDecoration(color: _highlightAnimation.value)
                        : null,
                    child: innerChild,
                  );
                },
                child: child,
              ),
            ),
          ),
        );
      },
      child: buildRowBody(),
    );
  }
}
