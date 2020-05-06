import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class MyCompositedTransformFollower extends SingleChildRenderObjectWidget {
  const MyCompositedTransformFollower({
    Key key,
    @required this.link,
    this.targetSize,
    this.childAnchor,
    this.portalAnchor,
    Widget child,
  }) : super(key: key, child: child);

  final Alignment childAnchor;
  final Alignment portalAnchor;
  final LayerLink link;
  final Size targetSize;

  @override
  MyRenderFollowerLayer createRenderObject(BuildContext context) {
    return MyRenderFollowerLayer(link: link)
      ..targetSize = targetSize
      ..childAnchor = childAnchor
      ..portalAnchor = portalAnchor;
  }

  @override
  void updateRenderObject(
      BuildContext context, MyRenderFollowerLayer renderObject) {
    renderObject
      ..link = link
      ..targetSize = targetSize
      ..childAnchor = childAnchor
      ..portalAnchor = portalAnchor;
  }
}

class MyRenderFollowerLayer extends RenderProxyBox {
  MyRenderFollowerLayer({
    @required LayerLink link,
    RenderBox child,
  })  : _link = link,
        super(child);

  Alignment _childAnchor;
  Alignment get childAnchor => _childAnchor;
  set childAnchor(Alignment childAnchor) {
    if (childAnchor != _childAnchor) {
      _childAnchor = childAnchor;
      markNeedsPaint();
    }
  }

  Alignment _portalAnchor;
  Alignment get portalAnchor => _portalAnchor;
  set portalAnchor(Alignment portalAnchor) {
    if (portalAnchor != _portalAnchor) {
      _portalAnchor = portalAnchor;
      markNeedsPaint();
    }
  }

  LayerLink get link => _link;
  LayerLink _link;
  set link(LayerLink value) {
    if (_link == value) return;
    if (_link == null || value == null) {
      markNeedsCompositingBitsUpdate();
      markNeedsLayoutForSizedByParentChange();
    }
    _link = value;
    markNeedsPaint();
  }

  Size get targetSize => _targetSize;
  Size _targetSize;
  set targetSize(Size value) {
    assert(value != null);
    if (_targetSize == value) return;
    _targetSize = value;
    markNeedsPaint();
  }

  @override
  void detach() {
    layer = null;
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => link != null;

  @override
  bool get sizedByParent => link == null;

  @override
  FollowerLayer get layer => super.layer as FollowerLayer;

  Matrix4 getCurrentTransform() {
    return layer?.getLastTransform() ?? Matrix4.identity();
  }

  @override
  bool hitTest(BoxHitTestResult result, {Offset position}) {
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {Offset position}) {
    if (link == null) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: getCurrentTransform(),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void performLayout() {
    if (sizedByParent) {
      child.layout(BoxConstraints.tight(size));
    } else {
      super.performLayout();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (link == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }

    final linkedOffset = childAnchor.withinRect(
          Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        ) -
        portalAnchor.withinRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (layer == null) {
      layer = FollowerLayer(
        link: link,
        showWhenUnlinked: false,
        linkedOffset: linkedOffset,
      );
    } else {
      layer
        ..link = link
        ..showWhenUnlinked = false
        ..linkedOffset = linkedOffset;
    }

    context.pushLayer(
      layer,
      super.paint,
      Offset.zero,
      childPaintBounds: const Rect.fromLTRB(
        // We don't know where we'll end up, so we have no idea what our cull rect should be.
        double.negativeInfinity,
        double.negativeInfinity,
        double.infinity,
        double.infinity,
      ),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (link != null) transform.multiply(getCurrentTransform());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('link', link));
    properties.add(
        TransformProperty('current transform matrix', getCurrentTransform()));

    properties.add(DiagnosticsProperty('childAnchor', childAnchor));
    properties.add(DiagnosticsProperty('portalAnchor', portalAnchor));
    properties.add(DiagnosticsProperty('targetSize', targetSize));
  }
}
