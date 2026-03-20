import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/push_notification/notification_content.dart';
import 'package:tungstn/client/room.dart';

abstract class Notifier {
  Future<void> notify(NotificationContent notification);

  bool get hasPermission;

  bool get needsToken;

  bool get enabled;

  Future<String?> getToken();

  Future<bool> requestPermission();

  Map<String, dynamic>? extraRegistrationData();

  Future<void> init();

  Future<void> clearNotifications(Room room);
}
