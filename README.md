[![Build Status](https://travis-ci.org/rrousselGit/flutter_portal.svg?branch=master)](https://travis-ci.org/rrousselGit/flutter_portal)
[![pub package](https://img.shields.io/pub/v/flutter_portal.svg)](https://pub.dartlang.org/packages/flutter_portal) [![codecov](https://codecov.io/gh/rrousselGit/flutter_portal/branch/master/graph/badge.svg)](https://codecov.io/gh/rrousselGit/flutter_portal)

## Motivation

Flutter comes with two classes for manipulating "overlays":

- [Overlay]
- [OverlayEntry]

But [OverlayEntry] is very awkward to use. As opposed to most of the framework,
[OverlayEntry] is **not** a widget (which comes with a nice and clean declarative API).

Instead, is uses an imperative API. This comes with a few drawbacks:

- a widget's life-cycle (like `initState`) _cannot_ add/remove synchronously an
  [OverlayEntry].

  This means the first rendering of our entry is effectively one frame late.

- It is difficult to align an [OverlayEntry] around a non-overlay widget
  (for example for a contextual menu).

  We basically have to do everything ourselves, usually needing an
  [addPostFrameCallback] which, again, makes the rendering of our overlay one frame late.

That's where `portal` comes into play.

This library is effectively a reimplementation of [Overlay]/[OverlayEntry], under
the name [Portal]/[PortalEntry] (the name that React uses for overlays) while
fixing all the previously mentioned issues.

## Install

First, you will need to add `portal` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_portal: ^0.2.0
```

Then, run `flutter packages get` in your terminal.

## Usage

To use `portal`, we have to rely on two widgets:

- [Portal], the equivalent of [Overlay].

  This widget will need to be inserted above the widget that needs to render
  _under_ your overlays.

  If you want to display your overlays on the top of _everything_, a good place
  to insert that [Portal] is above `MaterialApp`:

  ```dart
  Portal(
    child: MaterialApp(
      ...
    )
  );
  ```

  (works for `CupertinoApp` too)

  This way [Portal] will render above everything. But you could place it
  somewhere else to change the clip behavior.

* [PortalEntry] is the equivalent of [OverlayEntry].

  As opposed to [OverlayEntry], using `portal` then [PortalEntry] is a widget,
  and is therefore placed inside your widget tree (so the `build` method).

  Consider the following [OverlayEntry] example:

  ```dart
  class Example extends StatefulWidget {
    const Example({Key key, this.title}) : super(key: key);

    final String title;
    @override
    _ExampleState createState() => _ExampleState();
  }

  class _ExampleState extends State<Example> {
    OverlayEntry entry;

    @override
    void initState() {
      super.initState();
      entry = OverlayEntry(
        builder: (context) {
          return Text(widget.title);
        },
      );

      SchedulerBinding.instance.addPostFrameCallback((_) {
        Overlay.of(context).insert(entry);
      });
    }

    @override
    void dispose() {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        entry.remove();
      });
      super.dispose();
    }

    @override
    void didUpdateWidget(Example oldWidget) {
      super.didUpdateWidget(oldWidget);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        entry.markNeedsBuild();
      });
    }

    @override
    Widget build(BuildContext context) {
      return const Text('whatever');
    }
  }
  ```

  Using [PortalEntry] instead, we would write:

  ```dart
  class Example extends StatelessWidget {
    const Example({Key key, this.title}) : super(key: key);
    final String title;

    @override
    Widget build(BuildContext context) {
      return PortalEntry(
        portal: Align(
          alignment: Alignment.topLeft,
          child: Text(title)
        ),
        child: const Text('whatever'),
      );
    }
  }
  ```

  These two examples are identical in behavior:

  - When mounting our `Example` widget, an overlay is added, which is later
    removed when the widget is removed from the tree.
  - the content of that overlay is a `Text`, that may change over time based
    on a `title` variable.

  On the other hand, there's a difference:
  Using [PortalEntry] does **not** rely on [addPostFrameCallback].

  As such, inserting/updating our `Example` widget _immediatly_ inserts/updates the overlay, whereas using [OverlayEntry] the update is late by one frame.

### Aligning the overlay around a widget

Sometimes, we want to align our overlay around another widget.
[PortalEntry] comes with built-in support for this kind of feature.

For example, consider that we have a `Text` centered in our app:

```dart
Center(
  child: Text('whatever'),
)
```

If we wanted to add an overlay that is aligned on the top center of our `Text`,
we would write:

```dart
Center(
  child: PortalEntry(
    portalAnchor: Alignment.bottomCenter,
    childAnchor: Alignment.topCenter,
    portal: Card(child: Text('portal')),
    child: Text('whatever'),
  ),
)
```

This will align the top-center of `child` with the bottom-center of `portal`,
which renders the following:

<img src="https://raw.githubusercontent.com/rrousselGit/flutter_portal/master/resources/alignment.png" width="200" />

[overlay]: https://api.flutter.dev/flutter/widgets/Overlay-class.html
[overlayentry]: https://api.flutter.dev/flutter/widgets/OverlayEntry-class.html
[addpostframecallback]: https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html
[portal]: https://pub.dev/documentation/flutter_portal/latest/flutter_portal/Portal-class.html
[portalentry]: https://pub.dev/documentation/flutter_portal/latest/flutter_portal/PortalEntry-class.html
