import 'package:tungstn/client/components/push_notification/modifiers/notification_modifiers.dart';
import 'package:tungstn/client/components/push_notification/notification_content.dart';
import 'package:tungstn/config/build_config.dart';
import 'package:tungstn/utils/event_bus.dart';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class NotificationModifierSuppressActiveRoom implements NotificationModifier {
  String? roomId = "";

  NotificationModifierSuppressActiveRoom() {
    EventBus.onSelectedRoomChanged.stream.listen((event) {
      roomId = event?.identifier;
    });
  }

  @override
  Future<NotificationContent?> process(NotificationContent content) async {
    if (content is MessageNotificationContent) {
      if (BuildConfig.DESKTOP) {
        if (!await windowManager.isFocused()) {
          return content;
        }
      } else {
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return content;
        }
      }

      if (content.roomId == roomId) return null;
    }

    return content;
  }
}
