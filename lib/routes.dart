// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:dual_screen/dual_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery/deferred_widget.dart';
import 'package:gallery/main.dart';
import 'package:gallery/pages/demo.dart';
import 'package:gallery/pages/home.dart';
import 'package:gallery/studies/crane/app.dart' deferred as crane;
import 'package:gallery/studies/crane/routes.dart' as crane_routes;
import 'package:gallery/studies/fortnightly/app.dart' deferred as fortnightly;
import 'package:gallery/studies/fortnightly/routes.dart' as fortnightly_routes;
import 'package:gallery/studies/rally/app.dart' deferred as rally;
import 'package:gallery/studies/rally/routes.dart' as rally_routes;
import 'package:gallery/studies/reply/app.dart' as reply;
import 'package:gallery/studies/reply/routes.dart' as reply_routes;
import 'package:gallery/studies/shrine/app.dart' deferred as shrine;
import 'package:gallery/studies/shrine/routes.dart' as shrine_routes;
import 'package:gallery/studies/starter/app.dart' as starter_app;
import 'package:gallery/studies/starter/routes.dart' as starter_app_routes;

typedef PathWidgetBuilder = Widget Function(BuildContext, String?);

class Path {
  const Path(this.pattern, this.builder, {this.openInSecondScreen = false});

  /// A RegEx string for route matching.
  final String pattern;

  /// The builder for the associated pattern route. The first argument is the
  /// [BuildContext] and the second argument a RegEx match if that is included
  /// in the pattern.
  ///
  /// ```dart
  /// Path(
  ///   'r'^/demo/([\w-]+)$',
  ///   (context, matches) => Page(argument: match),
  /// )
  /// ```
  final PathWidgetBuilder builder;

  /// If the route should open on the second screen on foldables.
  final bool openInSecondScreen;
}

class RouteConfiguration {
  /// List of [Path] to for route matching. When a named route is pushed with
  /// [Navigator.pushNamed], the route name is matched with the [Path.pattern]
  /// in the list below. As soon as there is a match, the associated builder
  /// will be returned. This means that the paths higher up in the list will
  /// take priority.
  static List<Path> paths = [
    Path(
      r'^' + DemoPage.baseRoute + r'/([\w-]+)$',
      (context, match) => DemoPage(slug: match),
      openInSecondScreen: false,
    ),
    Path(
      r'^' + rally_routes.homeRoute,
      (context, match) => StudyWrapper(
        study: DeferredWidget(rally.loadLibrary,
            () => rally.RallyApp()), // ignore: prefer_const_constructors
      ),
      openInSecondScreen: true,
    ),
    Path(
      r'^' + shrine_routes.homeRoute,
      (context, match) => StudyWrapper(
        study: DeferredWidget(shrine.loadLibrary,
            () => shrine.ShrineApp()), // ignore: prefer_const_constructors
      ),
      openInSecondScreen: true,
    ),
    Path(
      r'^' + crane_routes.defaultRoute,
      (context, match) => StudyWrapper(
        study: DeferredWidget(crane.loadLibrary,
            () => crane.CraneApp(), // ignore: prefer_const_constructors
            placeholder: const DeferredLoadingPlaceholder(name: 'Crane')),
      ),
      openInSecondScreen: true,
    ),
    Path(
      r'^' + fortnightly_routes.defaultRoute,
      (context, match) => StudyWrapper(
        study: DeferredWidget(
            fortnightly.loadLibrary,
            // ignore: prefer_const_constructors
            () => fortnightly.FortnightlyApp()),
      ),
      openInSecondScreen: true,
    ),
    Path(
      r'^' + reply_routes.homeRoute,
      // ignore: prefer_const_constructors
      (context, match) =>
          const StudyWrapper(study: reply.ReplyApp(), hasBottomNavBar: true),
      openInSecondScreen: true,
    ),
    Path(
      r'^' + starter_app_routes.defaultRoute,
      (context, match) => const StudyWrapper(
        study: starter_app.StarterApp(),
      ),
      openInSecondScreen: true,
    ),
    Path(
      r'^/',
      (context, match) => const RootPage(),
      openInSecondScreen: false,
    ),
  ];

  /// The route generator callback used when the app is navigated to a named
  /// route. Set it on the [MaterialApp.onGenerateRoute] or
  /// [WidgetsApp.onGenerateRoute] to make use of the [paths] for route
  /// matching.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    for (final path in paths) {
      final regExpPattern = RegExp(path.pattern);
      if (regExpPattern.hasMatch(settings.name!)) {
        final firstMatch = regExpPattern.firstMatch(settings.name!)!;
        final match = (firstMatch.groupCount == 1) ? firstMatch.group(1) : null;
        if (kIsWeb) {
          return NoAnimationMaterialPageRoute<void>(
            builder: (context) => path.builder(context, match),
            settings: settings,
          );
        }
        if (path.openInSecondScreen) {
          return TwoPanePageRoute<void>(
            builder: (context) => path.builder(context, match),
            settings: settings,
          );
        } else {
          return ShaderPageRoute<void>(
            builder: (context) => path.builder(context, match),
            settings: settings,
          );
        }
      }
    }

    // If no match was found, we let [WidgetsApp.onUnknownRoute] handle it.
    return null;
  }
}

class NoAnimationMaterialPageRoute<T> extends MaterialPageRoute<T> {
  NoAnimationMaterialPageRoute({
    required super.builder,
    super.settings,
  });

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class TwoPanePageRoute<T> extends OverlayRoute<T> {
  TwoPanePageRoute({
    required this.builder,
    super.settings,
  });

  final WidgetBuilder builder;

  @override
  Iterable<OverlayEntry> createOverlayEntries() sync* {
    yield OverlayEntry(builder: (context) {
      final hinge = MediaQuery.of(context).hinge?.bounds;
      if (hinge == null) {
        return builder.call(context);
      } else {
        return Positioned(
            top: 0,
            left: hinge.right,
            right: 0,
            bottom: 0,
            child: builder.call(context));
      }
    });
  }
}

class FragmentProgramManager {
  static final Map<String, ui.FragmentProgram> _programs = <String, ui.FragmentProgram>{};

  static Future<void> initialize(String assetKey) async {
    if (!_programs.containsKey(assetKey)) {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        assetKey,
      );
      _programs.putIfAbsent(assetKey, () => program);
    }
  }

  static ui.FragmentProgram lookup(String assetKey) => _programs[assetKey]!;
}

class ShaderPageRoute<T> extends MaterialPageRoute<T> {
  ShaderPageRoute({
    required super.builder,
    super.settings,
  });

  ui.FragmentProgram get _program {
    return FragmentProgramManager.lookup(_shaderAssets[
      settings.name.hashCode % _shaderAssets.length
    ]);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_shadersInitialized) {
      _initializeShaders();
      return child;
    }
    return _ShaderPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      fragmentProgram: _program,
      child: child,
    );
  }

  static bool _shadersInitializing = false;
  static bool _shadersInitialized = false;
  static const List<String> _shaderAssets = <String>[
    'shaders/crossswap.frag',
    'shaders/curl_noise.frag',
    'shaders/fork_shutter.frag',
    'shaders/pixelated.frag',
    'shaders/random_squares.frag',
    'shaders/ripple.frag',
    'shaders/spooky_fade.frag',
    'shaders/zoom_blur.frag',
  ];
  static Future<void> _initializeShaders() async {
    if (_shadersInitialized || _shadersInitializing) {
      return;
    }
    _shadersInitializing = true;
    for (final String shaderAsset in _shaderAssets) {
      await FragmentProgramManager.initialize(shaderAsset);
    }
    _shadersInitialized = true;
    _shadersInitializing = false;
  }
}

class _ShaderPageTransition extends StatelessWidget {
  const _ShaderPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.fragmentProgram,
    this.child,
  }) : assert(animation != null),
       assert(secondaryAnimation != null);

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final ui.FragmentProgram fragmentProgram;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (
        BuildContext context,
        Animation<double> animation,
        Widget? child,
      ) {
        return _ShaderEnterTransition(
          animation: animation,
          fragmentProgram: fragmentProgram,
          child: child,
        );
      },
      reverseBuilder: (
        BuildContext context,
        Animation<double> animation,
        Widget? child,
      ) {
        return _ShaderEnterTransition(
          animation: animation,
          fragmentProgram: fragmentProgram,
          reverse: true,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _ShaderEnterTransition extends StatefulWidget {
  const _ShaderEnterTransition({
    required this.animation,
    this.reverse = false,
    required this.fragmentProgram,
    this.child,
  }) : assert(animation != null),
       assert(reverse != null);

  final Animation<double> animation;
  final Widget? child;
  final ui.FragmentProgram fragmentProgram;
  final bool reverse;

  @override
  State<_ShaderEnterTransition> createState() => _ShaderEnterTransitionState();
}

class _ShaderEnterTransitionState extends State<_ShaderEnterTransition> with _ShaderTransitionBase {
  @override
  bool get useSnapshot => !kIsWeb;

  late _ShaderEnterTransitionPainter delegate;

  static final Animatable<double> _shaderInTransition = Tween<double>(
    begin: 0.0,
    end: 1.00,
  );

  static final Animatable<double> _shaderOutTransition = Tween<double>(
    begin: 1.0,
    end: 0.00,
  );

  void _updateAnimations() {
    shaderTransition = (widget.reverse
      ? _shaderOutTransition
      : _shaderInTransition
    ).animate(widget.animation);

    widget.animation.addListener(onAnimationValueChange);
    widget.animation.addStatusListener(onAnimationStatusChange);
  }

  @override
  void initState() {
    _updateAnimations();
    delegate = _ShaderEnterTransitionPainter(
      animation: shaderTransition,
      fragmentProgram: widget.fragmentProgram,
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _ShaderEnterTransition oldWidget) {
    if (oldWidget.reverse != widget.reverse || oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(onAnimationStatusChange);
      _updateAnimations();
      delegate.dispose();
      delegate = _ShaderEnterTransitionPainter(
        animation: shaderTransition,
        fragmentProgram: widget.fragmentProgram,
      );
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.animation.removeListener(onAnimationValueChange);
    widget.animation.removeStatusListener(onAnimationStatusChange);
    delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnapshotWidget(
      painter: delegate,
      controller: controller,
      mode: SnapshotMode.permissive,
      child: widget.child,
    );
  }
}

mixin _ShaderTransitionBase {
  bool get useSnapshot;

  final SnapshotController controller = SnapshotController();

  late Animation<double> shaderTransition;

  void onAnimationValueChange() {
    if (shaderTransition.value == 1.0) {
      controller.allowSnapshotting = false;
    } else {
      controller.allowSnapshotting = useSnapshot;
    }
  }

  void onAnimationStatusChange(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        controller.allowSnapshotting = false;
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        controller.allowSnapshotting = useSnapshot;
        break;
    }
  }
}

final Float64List _identityMatrix = Float64List.fromList(<double>[
  1, 0, 0, 0,
  0, 1, 0, 0,
  0, 0, 1, 0,
  0, 0, 0, 1,
]);

class _ShaderEnterTransitionPainter extends SnapshotPainter {
  _ShaderEnterTransitionPainter({
    required this.animation,
    required ui.FragmentProgram fragmentProgram,
  }) {
    fragmentShader = fragmentProgram.fragmentShader();
    animation.addListener(notifyListeners);
  }

  final Animation<double> animation;
  late final ui.FragmentShader fragmentShader;

  ui.Image? _cachedImage;
  ImageShader? _cachedImageShader;

  @override
  void paint(
    PaintingContext context,
    ui.Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    painter(context, offset);
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    double pixelRatio,
  ) {
    final ImageShader imageShader = ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      _identityMatrix,
    );
    fragmentShader
      ..setFloat(0, animation.value)
      ..setFloat(1, size.width)
      ..setFloat(2, size.height)
      ..setSampler(0, imageShader);
    context.canvas.drawRect(
      offset & size,
      Paint()..shader = fragmentShader,
    );
  }

  @override
  void dispose() {
    animation.removeListener(notifyListeners);
    fragmentShader.dispose();
    _cachedImageShader?.dispose();
    super.dispose();
  }

  @override
  bool shouldRepaint(covariant _ShaderEnterTransitionPainter oldPainter) {
    return oldPainter.animation.value != animation.value;
  }
}
