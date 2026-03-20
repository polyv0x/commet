import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/timeline_events/timeline_event.dart';

abstract class TimelineEventEncrypted extends TimelineEvent {
  Future<TimelineEvent?> attemptDecrypt(Room room);
}
