import 'package:flutter/widgets.dart';

/// A piece of the screen that rebuilds only when what it shows changed.
///
/// Listens to [listenable] (the game controller notifies every tick). On each
/// notice it reads [select] — a record of the fields [builder] shows — and
/// rebuilds only if the value differs (`==`). Records compare field by field;
/// lists and sets inside compare by identity, and the game replaces them
/// whenever their content changes.
class GameSelector<T> extends StatefulWidget {
  const GameSelector({
    super.key,
    required this.listenable,
    required this.select,
    required this.builder,
  });

  final Listenable listenable;
  final T Function() select;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<GameSelector<T>> createState() => _GameSelectorState<T>();
}

class _GameSelectorState<T> extends State<GameSelector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select();
    widget.listenable.addListener(_onNotice);
  }

  @override
  void didUpdateWidget(covariant GameSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onNotice);
      widget.listenable.addListener(_onNotice);
    }
    _value = widget.select();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onNotice);
    super.dispose();
  }

  void _onNotice() {
    if (!mounted) return;
    final next = widget.select();
    if (next == _value) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
