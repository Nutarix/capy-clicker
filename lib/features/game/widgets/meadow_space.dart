import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Screen ↔ meadow (spec 003, Т2). One helper for the drag, the magnet, the
/// puddle, the places, the merge on release and the floating labels.
///
/// Goes through the meadow's own render box: its transform already holds
/// where the meadow sits on screen, the camera zoom (also mid-ease) and the
/// zoom center. The box hands itself over while attached
/// ([MeadowSpaceAnchor]), so this works the same in debug and release.
class MeadowSpace {
  RenderBox? _box;

  /// Laid out and on screen.
  bool get isReady {
    final box = _box;
    return box != null && box.attached && box.hasSize;
  }

  /// Unscaled meadow size (null until laid out).
  Size? get size => isReady ? _box!.size : null;

  /// Screen point → meadow pixels (unscaled).
  Offset? globalToLocal(Offset global) =>
      isReady ? _box!.globalToLocal(global) : null;

  /// Screen point → normalized meadow point (0–1 on each axis).
  Offset? toNormalized(Offset global) {
    if (!isReady) return null;
    final box = _box!;
    final local = box.globalToLocal(global);
    return Offset(local.dx / box.size.width, local.dy / box.size.height);
  }

  /// Normalized meadow point → screen point.
  Offset? toGlobal(Offset normalized) {
    if (!isReady) return null;
    final box = _box!;
    return box.localToGlobal(
      Offset(normalized.dx * box.size.width, normalized.dy * box.size.height),
    );
  }

  /// Screen pixels per meadow pixel right now (the camera zoom). 1 when the
  /// meadow is not laid out.
  double get scale {
    if (!isReady) return 1;
    final box = _box!;
    final a = box.localToGlobal(Offset.zero);
    final b = box.localToGlobal(const Offset(100, 0));
    final s = (b - a).distance / 100;
    return s > 0 ? s : 1;
  }
}

/// Puts the meadow's render box into [space] while it is attached.
///
/// A detached box (the meadow was rebuilt elsewhere, e.g. the rocket toggled
/// the bars) is dropped, so nobody reads a defunct render object.
class MeadowSpaceAnchor extends SingleChildRenderObjectWidget {
  const MeadowSpaceAnchor({super.key, required this.space, super.child});

  final MeadowSpace space;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeadowAnchor(space);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeadowAnchor).space = space;
  }
}

class _RenderMeadowAnchor extends RenderProxyBox {
  _RenderMeadowAnchor(this._space);

  MeadowSpace _space;

  set space(MeadowSpace value) {
    if (identical(value, _space)) return;
    if (identical(_space._box, this)) _space._box = null;
    _space = value;
    if (attached) _space._box = this;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _space._box = this;
  }

  @override
  void detach() {
    if (identical(_space._box, this)) _space._box = null;
    super.detach();
  }
}
