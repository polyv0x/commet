import 'package:tungstn/client/attachment.dart';
import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/component.dart';
import 'package:tungstn/client/timeline_events/timeline_event.dart';

abstract class ThreadsComponent<T extends Client> implements Component<T> {
  bool isEventInResponseToThread(TimelineEvent event, Timeline timeline);

  bool isHeadOfThread(TimelineEvent event, Timeline timeline);

  Future<Timeline?> getThreadTimeline(
      {required Timeline roomTimeline, required String threadRootEventId});

  Future<TimelineEvent?> sendMessage({
    required String threadRootEventId,
    required Room room,
    String? message,
    TimelineEvent? inReplyTo,
    TimelineEvent? replaceEvent,
    List<ProcessedAttachment>? processedAttachments,
  });

  TimelineEvent? getFirstReplyToThread(TimelineEvent event, Timeline timeline);
}
