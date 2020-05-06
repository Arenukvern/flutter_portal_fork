import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_portal/src/custom_follower.dart';

class Portal extends StatefulWidget {
  const Portal({Key key, @required this.child})
      : assert(child != null),
        super(key: key);

  final Widget child;

  @override
  _PortalState createState() => _PortalState();
}

class _PortalState extends State<Portal> {
  final _OverlayLink overlayLink = _OverlayLink();

  @override
  Widget build(BuildContext context) {
    return _PortalLinkScope(
      overlayLink: overlayLink,
      child: _PortalTheater(
        overlayLink: overlayLink,
        child: widget.child,
      ),
    );
  }
}

class _OverlayLink {
  RenderPortalTheater theater;
  BoxConstraints get constraints => theater.constraints;

  final Set<RenderBox> overlays = {};
}

class _PortalLinkScope extends InheritedWidget {
  const _PortalLinkScope({
    Key key,
    @required this.overlayLink,
    @required Widget child,
  }) : super(key: key, child: child);

  final _OverlayLink overlayLink;

  @override
  bool updateShouldNotify(_PortalLinkScope oldWidget) {
    return oldWidget.overlayLink != overlayLink;
  }
}

class _PortalTheater extends SingleChildRenderObjectWidget {
  const _PortalTheater({
    Key key,
    @required this.overlayLink,
    @required Widget child,
  }) : super(key: key, child: child);

  final _OverlayLink overlayLink;

  @override
  RenderPortalTheater createRenderObject(BuildContext context) {
    return RenderPortalTheater(overlayLink);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPortalTheater renderObject,
  ) {
    renderObject.overlayLink = overlayLink;
  }
}

class RenderPortalTheater extends RenderProxyBox {
  RenderPortalTheater(_OverlayLink _overlayLink) {
    overlayLink = _overlayLink;
  }

  _OverlayLink _overlayLink;
  _OverlayLink get overlayLink => _overlayLink;
  set overlayLink(_OverlayLink value) {
    assert(value != null);
    if (_overlayLink != value) {
      assert(value.theater == null);
      _overlayLink?.theater = null;
      _overlayLink = value;
      value.theater = this;
    }
  }

  @override
  void markNeedsLayout() {
    for (final overlay in overlayLink.overlays) {
      overlay.markNeedsLayout();
    }
    super.markNeedsLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    for (var i = overlayLink.overlays.length - 1; i >= 0; i--) {
      final overlay = overlayLink.overlays.elementAt(i);

      context.paintChild(overlay, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {Offset position}) {
    for (final overlay in overlayLink.overlays) {
      if (overlay?.hitTest(result, position: position) ?? false) {
        return true;
      }
    }

    return super.hitTestChildren(result, position: position);
  }
}

class PortalEntry extends StatefulWidget {
  PortalEntry({
    Key key,
    bool visible = true,
    this.childAnchor,
    this.portalAnchor,
    Widget portal,
    @required this.child,
  })  : assert(child != null),
        assert(visible == false || portal != null),
        assert((childAnchor == null) == (portalAnchor == null)),
        portal = visible ? portal : null,
        super(key: key);

  final Alignment portalAnchor;
  final Alignment childAnchor;
  final Widget portal;
  final Widget child;

  @override
  _PortalEntryState createState() => _PortalEntryState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Alignment>('portalAnchor', portalAnchor))
      ..add(DiagnosticsProperty<Alignment>('childAnchor', childAnchor))
      ..add(DiagnosticsProperty<Widget>('portal', portal))
      ..add(DiagnosticsProperty<Widget>('child', child));
  }
}

class _PortalEntryState extends State<PortalEntry> {
  final link = LayerLink();
  @override
  Widget build(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_PortalLinkScope>();
    if (scope == null) {
      throw PortalNotFoundError._(widget);
    }

    if (widget.portal == null || widget.portalAnchor == null) {
      return _PortalEntryTheater(
        portal: widget.portal,
        overlayLink: scope.overlayLink,
        child: widget.child,
      );
    }

    return Stack(
      children: <Widget>[
        CompositedTransformTarget(
          link: link,
          child: widget.child,
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _PortalEntryTheater(
                overlayLink: scope.overlayLink,
                loosen: true,
                portal: MyCompositedTransformFollower(
                  link: link,
                  childAnchor: widget.childAnchor,
                  portalAnchor: widget.portalAnchor,
                  targetSize: constraints.biggest,
                  child: widget.portal,
                ),
                child: const SizedBox.shrink(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PortalEntryTheater extends SingleChildRenderObjectWidget {
  _PortalEntryTheater({
    Key key,
    @required this.portal,
    @required this.overlayLink,
    this.loosen = false,
    @required Widget child,
  })  : assert(child != null),
        assert(overlayLink != null),
        super(key: key, child: child);

  final Widget portal;
  final bool loosen;
  final _OverlayLink overlayLink;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPortalEntry(overlayLink, loosen: loosen);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPortalEntry renderObject,
  ) {
    renderObject
      ..overlayLink = overlayLink
      ..loosen = loosen;
  }

  @override
  SingleChildRenderObjectElement createElement() => PortalEntryElement(this);
}

class _RenderPortalEntry extends RenderProxyBox {
  _RenderPortalEntry(this._overlayLink, {@required bool loosen}) {
    this.loosen = loosen;
  }

  bool _needsAddEntryInTheater = false;

  _OverlayLink _overlayLink;
  _OverlayLink get overlayLink => _overlayLink;
  set overlayLink(_OverlayLink value) {
    assert(value != null);
    assert(value.theater != null);
    if (_overlayLink != value) {
      _overlayLink = value;
      markNeedsLayout();
    }
  }

  bool _loosen;
  bool get loosen => _loosen;
  set loosen(bool value) {
    if (value != _loosen) {
      _loosen = value;
      markNeedsLayout();
    }
  }

  RenderBox _branch;
  RenderBox get branch => _branch;
  set branch(RenderBox value) {
    if (_branch != null) {
      _overlayLink.overlays.remove(branch);
      _overlayLink.theater.markNeedsPaint();
      dropChild(_branch);
    }
    _branch = value;
    if (_branch != null) {
      markNeedsAddEntryInTheater();
      adoptChild(_branch);
    }
  }

  void markNeedsAddEntryInTheater() {
    _needsAddEntryInTheater = true;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_branch != null) {
      markNeedsAddEntryInTheater();
      _branch.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    if (_branch != null) {
      _overlayLink.overlays.remove(branch);
      _overlayLink.theater.markNeedsPaint();
      _branch.detach();
    }
  }

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    overlayLink.theater.markNeedsPaint();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (branch != null) {
      if (loosen) {
        branch.layout(overlayLink.constraints.loosen());
      } else {
        branch.layout(BoxConstraints.tight(overlayLink.constraints.biggest));
      }
      if (_needsAddEntryInTheater) {
        _needsAddEntryInTheater = false;
        _overlayLink.overlays.add(branch);
        _overlayLink.theater.markNeedsPaint();
      }
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    if (child == branch) {
      // ignore all transformations applied between Portal and PortalEntry
      transform.setFrom(overlayLink.theater.getTransformTo(null));
    }
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    if (branch != null) redepthChild(branch);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    if (branch != null) visitor(branch);
  }
}

class PortalEntryElement extends SingleChildRenderObjectElement {
  PortalEntryElement(_PortalEntryTheater widget) : super(widget);

  @override
  _PortalEntryTheater get widget => super.widget as _PortalEntryTheater;

  @override
  _RenderPortalEntry get renderObject =>
      super.renderObject as _RenderPortalEntry;

  Element _branch;

  final _branchSlot = 42;

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _branch = updateChild(_branch, widget.portal, _branchSlot);
  }

  @override
  void update(SingleChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    _branch = updateChild(_branch, widget.portal, _branchSlot);
  }

  @override
  void visitChildren(visitor) {
    // branch first so that it is unmounted before the main tree
    if (_branch != null) {
      visitor(_branch);
    }
    super.visitChildren(visitor);
  }

  @override
  void forgetChild(Element child) {
    if (child == _branch) {
      _branch = null;
    } else {
      super.forgetChild(child);
    }
  }

  @override
  void insertChildRenderObject(RenderObject child, dynamic slot) {
    if (slot == _branchSlot) {
      renderObject.branch = child as RenderBox;
    } else {
      super.insertChildRenderObject(child, slot);
    }
  }

  @override
  void moveChildRenderObject(RenderObject child, dynamic slot) {
    if (slot != _branchSlot) {
      super.moveChildRenderObject(child, slot);
    }
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    if (child == renderObject.branch) {
      renderObject.branch = null;
    } else {
      super.removeChildRenderObject(child);
    }
  }
}

/// The error that will be thrown if [_PortalEntryTheater] fails to find the specified [Portal].
class PortalNotFoundError<T extends Portal> extends Error {
  PortalNotFoundError._(this._portalEntry);

  final PortalEntry _portalEntry;

  @override
  String toString() {
    return '''
Error: Could not find a $T above this $_portalEntry.
''';
  }
}
