import 'package:tungstn/client/components/emoticon/emoticon.dart';
import 'package:tungstn/client/timeline.dart';

abstract class TimelineEventFeatureReactions {
  bool hasReactions(Timeline timeline);

  Map<Emoticon, Set<String>> getReactions(Timeline timeline);
}
