import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/component.dart';
import 'package:tungstn/client/timeline_events/timeline_event.dart';

abstract class MessageEffectComponent<T extends Client>
    implements Component<T> {
  void doEffect(TimelineEvent event);

  bool hasEffect(TimelineEvent event);
}
