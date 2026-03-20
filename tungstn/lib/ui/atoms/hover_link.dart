import 'package:tungstn/utils/links/link_utils.dart';
import 'package:flutter/material.dart';
import 'package:tiamat/config/style/theme_extensions.dart';

/// A widget that wraps [builder] with a pointer cursor and passes the current
/// hover state so the caller can apply decoration however the child requires.
class HoverLink extends StatefulWidget {
  const HoverLink({super.key, required this.builder, this.onTap});

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;

  @override
  State<HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<HoverLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: widget.builder(context, _hovered),
        ),
      ),
    );
  }
}

/// A text widget styled identically to inline chat links — same color,
/// pointer cursor, underline on hover. Pass [uri] and [clientId] to open
/// via [LinkUtils.open] (handles matrix: URIs, client routing, etc.).
class LinkText extends StatelessWidget {
  const LinkText(
    this.text, {
    super.key,
    this.uri,
    this.clientId,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final Uri? uri;
  final String? clientId;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).extension<ExtraColors>()?.linkColor ??
        Theme.of(context).colorScheme.primary;

    return HoverLink(
      onTap: uri != null
          ? () => LinkUtils.open(uri!, clientId: clientId, context: context)
          : null,
      builder: (context, hovered) => Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: (style ?? const TextStyle()).copyWith(
          color: color,
          decoration:
              hovered ? TextDecoration.underline : TextDecoration.none,
          decorationColor: color,
        ),
      ),
    );
  }
}
