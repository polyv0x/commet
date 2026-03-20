import 'package:tungstn/client/components/voip/android_screencapture_source.dart';
import 'package:tungstn/client/components/voip/voip_session.dart';
import 'package:tungstn/config/platform_utils.dart';
import 'package:tungstn/ui/organisms/call_view/screen_capture_source_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:tiamat/atoms/popup_dialog.dart';

class WebrtcScreencaptureSource implements ScreenCaptureSource {
  DesktopCapturerSource source;

  WebrtcScreencaptureSource(this.source);

  static Future<ScreenCaptureSource?> showSelectSourcePrompt(
      BuildContext context) async {
    if (PlatformUtils.isAndroid) {
      return WebrtcAndroidScreencaptureSource.getCaptureSource(context);
    }

    bool isWayland = PlatformUtils.displayServer == "wayland";

    var sources = await desktopCapturer.getSources(
      types: [if (!isWayland) SourceType.Window, SourceType.Screen],
    );

    if (isWayland && sources.isNotEmpty) {
      return WebrtcScreencaptureSource(sources.first);
    }

    if (context.mounted) {
      var result = await PopupDialog.show<DesktopCapturerSource>(context,
          content: ScreenCaptureSourceDialog(
              sources, desktopCapturer.onThumbnailChanged.stream),
          title: "Screen Share");

      if (result != null) {
        return WebrtcScreencaptureSource(result);
      }
    }

    return null;
  }
}
