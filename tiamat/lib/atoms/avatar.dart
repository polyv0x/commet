import 'package:flutter/material.dart';
import 'package:tiamat/utils.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: Avatar)
Widget wbavatarDefault(BuildContext context) {
  return const Center(
      child: Avatar(
    image: AssetImage("assets/images/placeholder/generic/checker_purple.png"),
  ));
}

@UseCase(name: 'Large', type: Avatar)
Widget wbavatarLarge(BuildContext context) {
  return const Center(
      child: Avatar.large(
    image: AssetImage("assets/images/placeholder/generic/checker_purple.png"),
  ));
}

@UseCase(name: 'Placeholder', type: Avatar)
Widget wbavatarPlaceholder(BuildContext context) {
  return const Center(
      child: Avatar(
    placeholderText: "A",
  ));
}

@UseCase(name: 'Placeholder Large', type: Avatar)
Widget wbavatarPlaceholderLarge(BuildContext context) {
  return const Center(
      child: Avatar.large(
    placeholderText: "A",
  ));
}

class Avatar extends StatelessWidget {
  const Avatar(
      {Key? key,
      this.image,
      this.radius = 22,
      this.placeholderText,
      this.placeholderColor,
      this.border,
      this.isPadding = false})
      : super(key: key);

  const Avatar.small({
    Key? key,
    this.image,
    this.placeholderText,
    this.placeholderColor,
    this.border,
    this.isPadding = false,
  })  : radius = 15,
        super(key: key);

  const Avatar.medium(
      {Key? key,
      required this.image,
      this.placeholderText,
      this.placeholderColor,
      this.border,
      this.isPadding = false})
      : radius = 22,
        super(key: key);

  const Avatar.large(
      {Key? key,
      this.image,
      this.placeholderText,
      this.placeholderColor,
      this.border,
      this.isPadding = false})
      : radius = 44,
        super(key: key);

  const Avatar.extraLarge(
      {Key? key,
      this.image,
      this.placeholderText,
      this.placeholderColor,
      this.border,
      this.isPadding = false})
      : radius = 80,
        super(key: key);

  final double radius;
  final ImageProvider? image;
  final String? placeholderText;
  final Color? placeholderColor;
  final BoxBorder? border;
  final bool isPadding;

  @override
  Widget build(BuildContext context) {
    if (isPadding) {
      return SizedBox(
        width: radius * 2,
        height: 1,
      );
    }

    final color = placeholderColor ?? Colors.transparent;
    final hsl = HSLColor.fromColor(color);
    final color2 = hsl.withHue((hsl.hue + 40) % 360).toColor();

    final placeholder = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: placeholderText != null
          ? DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color2, color],
                  ),
                  border: border),
              child: Align(
                  alignment: Alignment.center,
                  child: placeholderText!.isNotEmpty
                      ? Text(
                          placeholderText!.characters.first.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(fontSize: radius),
                        )
                      : null),
            )
          : null,
    );

    if (image == null) return placeholder;

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          DecoratedBox(
            decoration: BoxDecoration(
              border: border,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: FadeInImage(
                placeholder: transparentImage.image,
                fadeInDuration: Durations.short2,
                image: image!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                imageErrorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
