import 'package:flutter/material.dart';

/// iOS / SwiftUI-style grouped-list building blocks.

/// A small, grey, letter-spaced section header — like a `Section` header in
/// a SwiftUI `List` with `.insetGrouped` style.
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A rounded card that stacks its children with hairline separators between
/// them (inset to align under the row text), mimicking an inset-grouped list.
class GroupedCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  /// Left inset for the hairline separators (aligns past a leading icon).
  final double separatorIndent;

  const GroupedCard({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.separatorIndent = 52,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Divider(
          height: 0.5,
          thickness: 0.5,
          indent: separatorIndent,
          color: Theme.of(context).colorScheme.outlineVariant,
        ));
      }
    }

    return Padding(
      padding: margin,
      child: Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// Small caption text shown below a grouped card (footnote in SwiftUI).
class SectionFootnote extends StatelessWidget {
  final String text;

  const SectionFootnote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
