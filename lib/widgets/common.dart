import 'package:flutter/material.dart';
import 'package:shine_kit/shine_kit.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Gives every screen the app's [AppState].
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// The wordmark: "dr" in indigo, "shine" in ink.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return KitWordmark(prefix: 'dr', word: 'shine', size: size);
  }
}

/// A white rounded tile.
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: p.tile,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KitSize.tileRadius),
        side: border == null
            ? BorderSide.none
            : BorderSide(color: border!, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A big bold page title with a quiet line under it.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.kit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: KitType.display(38, color: p.ink)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: KitType.body(color: p.secondary)),
        ],
      ],
    );
  }
}

/// A small uppercase-free section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: KitType.eyebrow(color: context.kit.secondary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A soft pill for statuses.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? p.accentSoft : context.kit.inset,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: strong ? p.accent : p.secondary,
        ),
      ),
    );
  }
}

/// A calm inline message for errors.
class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.danger = false,
  });

  final String text;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = danger ? Brand.danger : p.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? Brand.danger.withValues(alpha: 0.08) : p.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: p.ink)),
          ),
        ],
      ),
    );
  }
}

/// A round letter avatar (never a patient photo).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.size = 44});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          color: p.accent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// A centered empty or loading state.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    super.key,
    required this.title,
    this.text,
    this.icon,
    this.action,
  });

  final String title;
  final String? text;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 40, color: p.secondary),
            if (icon != null) const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(
                text!,
                style: TextStyle(color: p.secondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
