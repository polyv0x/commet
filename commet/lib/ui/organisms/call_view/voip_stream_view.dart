import 'dart:async';
import 'dart:ui' as ui;

import 'package:commet/client/components/voip/voip_session.dart';
import 'package:commet/client/components/voip/voip_stream.dart';
import 'package:commet/client/member.dart';
import 'package:commet/debug/log.dart';
import 'package:commet/ui/organisms/call_view/call_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:tiamat/tiamat.dart' as tiamat;

class VoipStreamView extends StatefulWidget {
  const VoipStreamView(this.stream, this.session,
      {super.key,
      this.fit = BoxFit.cover,
      this.borderColor,
      this.canFullscreen = true,
      this.onFullscreen});
  final VoipStream stream;
  final VoipSession session;
  final BoxFit fit;
  final Function()? onFullscreen;
  final Color? borderColor;
  final bool canFullscreen;

  @override
  State<VoipStreamView> createState() => _VoipStreamViewState();
}

class _VoipStreamViewState extends State<VoipStreamView>
    with TickerProviderStateMixin {
  late Member user;
  Color? _avatarColor;

  late AnimationController audioLevel;
  late List<StreamSubscription> subs;
  bool _hovered = false;

  late GlobalKey rendererKey = GlobalKey();

  @override
  void initState() {
    Log.d("Initializing stream view!");
    var room = widget.session.client.getRoom(widget.session.roomId)!;
    subs = [
      widget.stream.onStreamChanged.listen(onStreamChanged),
      widget.stream.onAudioLevelChanged.listen((_) => timer()),
      widget.session.onUpdateVolumeVisualizers.listen((_) => timer()),
    ];
    user = room.getMemberOrFallback(widget.stream.streamUserId);

    audioLevel = AnimationController(
        vsync: this, duration: CallView.volumeAnimationDuration);
    _loadAvatarColor();
    super.initState();
  }

  @override
  void dispose() {
    audioLevel.stop();
    for (var sub in subs) sub.cancel();
    super.dispose();
  }

  Future<void> _loadAvatarColor() async {
    final avatar = user.avatar;
    if (avatar == null) return;
    try {
      final ImageStream stream =
          avatar.resolve(const ImageConfiguration(size: Size(32, 32)));
      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      }, onError: (_, __) {
        stream.removeListener(listener);
      });
      stream.addListener(listener);
      final image = await completer.future;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      int r = 0, g = 0, b = 0, count = 0;
      for (int i = 0; i < bytes.length; i += 4) {
        final alpha = bytes[i + 3];
        if (alpha < 128) continue;
        r += bytes[i];
        g += bytes[i + 1];
        b += bytes[i + 2];
        count++;
      }
      if (count == 0) return;
      final avg = Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
      if (mounted) setState(() => _avatarColor = avg);
    } catch (_) {}
  }

  void timer() {
    final target = widget.stream.audiolevel;
    final rising = target > audioLevel.value;
    audioLevel.animateTo(
      target,
      duration: rising
          ? const Duration(milliseconds: 80)
          : const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedBuilder(
          animation: audioLevel,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                    clipBehavior: Clip.antiAlias,
                    foregroundDecoration: widget.borderColor != null
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: widget.borderColor!,
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignCenter))
                        : null,
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: buildDefault()),
                if (widget.canFullscreen &&
                        widget.stream.type == VoipStreamType.video ||
                    widget.stream.type == VoipStreamType.screenshare)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: tiamat.IconButton(
                      icon: Icons.fullscreen,
                      size: 20,
                      onPressed: widget.onFullscreen,
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
    );
  }

  Widget buildDefault() {
    switch (widget.stream.type) {
      case VoipStreamType.audio:
        final baseHsl = HSLColor.fromColor(
                _avatarColor ?? user.defaultColor)
            .withSaturation(0.55);
        final color1 = baseHsl.withLightness(0.10).toColor();
        final color2 = baseHsl.withLightness(0.20).toColor();
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color1, color2],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
              child: Stack(
            alignment: AlignmentGeometry.bottomRight,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedOpacity(
                  opacity: widget.stream.isMuted ? 0.5 : 1.0,
                  duration: Duration(milliseconds: 200),
                  child: SizedBox(
                    width: 108,
                    height: 108,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: getBorderColor(context),
                              width: clampDouble(audioLevel.value * 15, 0, 5),
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                          ),
                        ),
                        ClipOval(
                          child: tiamat.Avatar(
                              radius: 50,
                              image: user.avatar,
                              placeholderColor: user.defaultColor,
                              placeholderText: user.displayName),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedScale(
                scale: widget.stream.isMuted ? 1.0 : 0.0,
                curve: widget.stream.isMuted
                    ? Curves.bounceOut
                    : Curves.easeInExpo,
                duration:
                    Duration(milliseconds: widget.stream.isMuted ? 500 : 200),
                child: Container(
                  decoration: BoxDecoration(
                      color: ColorScheme.of(context).primary,
                      borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.mic_off_rounded,
                      size: 18,
                      color: ColorScheme.of(context).onPrimary,
                    ),
                  ),
                ),
              )
            ],
          )),
        );

      case VoipStreamType.video:
      case VoipStreamType.screenshare:
        return Center(
          child: widget.stream.buildVideoRenderer(widget.fit, rendererKey) ??
              const CircularProgressIndicator(),
        );
    }
  }

  Color getBorderColor(BuildContext context) {
    return Color.lerp(Theme.of(context).primaryColor,
        Theme.of(context).colorScheme.primary, audioLevel.value)!;
  }

  void onStreamChanged(void event) {
    print("Stream state changed!");
    setState(() {});
  }
}
