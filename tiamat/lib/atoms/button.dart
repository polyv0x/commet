import 'package:flutter/material.dart';
import 'package:tiamat/config/style/theme_extensions.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';
import 'package:tiamat/tiamat.dart' as tiamat;

@UseCase(name: 'Default', type: Button)
Widget wbButton(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(width: 200, height: 50, child: Center(child: Button())),
        SizedBox(
          width: 200,
          height: 50,
          child: Center(child: Button.secondary()),
        ),
        SizedBox(
          width: 200,
          height: 50,
          child: Center(child: Button.success()),
        ),
        SizedBox(width: 200, height: 50, child: Center(child: Button.danger())),
        SizedBox(
          width: 200,
          height: 50,
          child: Center(child: Button.critical()),
        ),
        SizedBox(
          width: 200,
          height: 50,
          child: Center(child: Button(isLoading: true)),
        ),
      ],
    ),
  );
}

enum ButtonType { primary, secondary, success, danger, critical, gradient }

const _kLargeGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: [0.0, 0.30, 0.60, 1.0],
  colors: [
    Color(0xFFC084FC),
    Color(0xFF818CF8),
    Color(0xFF6366F1),
    Color(0xFF4F46E5),
  ],
);

class Button extends StatelessWidget {
  const Button({
    super.key,
    this.text = "Hello, World!",
    this.onTap,
    this.isLoading,
    this.type = ButtonType.primary,
  });
  final ButtonType type;
  final String text;
  final Function? onTap;
  final bool? isLoading;

  const Button.secondary({
    Key? key,
    this.text = "Hello, World!",
    this.onTap,
    this.isLoading,
  })  : type = ButtonType.secondary,
        super(key: key);

  const Button.success({
    Key? key,
    this.text = "Hello, World!",
    this.onTap,
    this.isLoading,
  })  : type = ButtonType.success,
        super(key: key);

  const Button.danger({
    Key? key,
    this.text = "Hello, World!",
    this.onTap,
    this.isLoading,
  })  : type = ButtonType.danger,
        super(key: key);

  const Button.critical({
    Key? key,
    this.text = "Hello, World!",
    this.onTap,
    this.isLoading,
  })  : type = ButtonType.critical,
        super(key: key);

  const Button.gradient({
    Key? key,
    this.text = "Hello, World!",
    this.onTap,
    this.isLoading,
  })  : type = ButtonType.gradient,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    ButtonStyle? style;

    switch (type) {
      case ButtonType.primary:
        // Fall through to gradient rendering.
        return _buildGradientButton(context);
      case ButtonType.secondary:
        style = Theme.of(context).elevatedButtonTheme.style?.copyWith(
              foregroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.secondaryContainer,
              ),
            );
        break;
      case ButtonType.success:
        style = Theme.of(context).elevatedButtonTheme.style?.copyWith(
              backgroundColor: WidgetStatePropertyAll(Colors.green.shade400),
            );

        break;
      case ButtonType.danger:
        style = Theme.of(context).elevatedButtonTheme.style?.copyWith(
              backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              shadowColor: const WidgetStatePropertyAll(Colors.transparent),
              side: WidgetStatePropertyAll(
                BorderSide(
                    color: Theme.of(context).colorScheme.error, width: 1),
              ),
            );
        break;
      case ButtonType.critical:
        style = Theme.of(context).elevatedButtonTheme.style?.copyWith(
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.error,
              ),
            );
        break;
      case ButtonType.gradient:
        return _buildGradientButton(context);
    }

    return ElevatedButton(
      style: style,
      onPressed: isLoading == true
          ? null
          : () {
              onTap?.call();
            },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading == true
            ? makeLoadingIndicator(context, style?.foregroundColor?.resolve({}))
            : tiamat.Text(text, color: style?.foregroundColor?.resolve({})),
      ),
    );
  }

  Widget _buildGradientButton(BuildContext context) {
    final enabled = onTap != null && isLoading != true;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? _kLargeGradient : null,
        color: enabled
            ? null
            : Theme.of(context).colorScheme.onSurface.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? () => onTap?.call() : null,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: isLoading == true
                  ? makeLoadingIndicator(context, Colors.white)
                  : tiamat.Text(text, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget makeLoadingIndicator(BuildContext context, Color? color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: tiamat.Text.label(text)),
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
