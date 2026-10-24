import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';

/// Durations for the app's motion system. When animations are disabled every
/// duration becomes zero, so widgets finish immediately without branching at
/// each call site.
class AppMotion {
  const AppMotion._();

  static MotionPreset presetOf(BuildContext context) => context
      .select<SettingsController, MotionPreset>((value) => value.motionPreset);

  static bool enabledOf(BuildContext context) => context
      .select<SettingsController, bool>((value) => value.animationsEnabled);

  static Duration fast(BuildContext context) =>
      _duration(context, subtle: 110, normal: 160, lively: 220);

  static Duration normal(BuildContext context) =>
      _duration(context, subtle: 180, normal: 260, lively: 360);

  static Duration slow(BuildContext context) =>
      _duration(context, subtle: 280, normal: 420, lively: 620);

  static Duration stagger(BuildContext context) =>
      _duration(context, subtle: 22, normal: 40, lively: 60);

  static Duration _duration(
    BuildContext context, {
    required int subtle,
    required int normal,
    required int lively,
  }) {
    if (!enabledOf(context)) return Duration.zero;
    return Duration(
      milliseconds: switch (presetOf(context)) {
        MotionPreset.subtle => subtle,
        MotionPreset.normal => normal,
        MotionPreset.lively => lively,
      },
    );
  }
}

/// Fades and lifts a child into place once. [index] staggers a list of items.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final double offset;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final delay = AppMotion.stagger(context) * widget.index.clamp(0, 8);
      _timer = Timer(delay, () {
        if (mounted) setState(() => _visible = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppMotion.enabledOf(context)) return widget.child;
    return AnimatedSlide(
      offset: _visible ? Offset.zero : Offset(0, widget.offset / 100),
      duration: AppMotion.normal(context),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: AppMotion.normal(context),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A page transition that respects the motion setting. The default Material
/// transition is replaced by a short fade-and-slide.
class HadesPageTransitionsBuilder extends PageTransitionsBuilder {
  const HadesPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!context.read<SettingsController>().animationsEnabled) return child;
    final preset = context.read<SettingsController>().motionPreset;
    final distance = switch (preset) {
      MotionPreset.subtle => 0.02,
      MotionPreset.normal => 0.05,
      MotionPreset.lively => 0.09,
    };
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, distance),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
