import 'package:tungstn/client/timeline.dart';

abstract class TimelineEventFeatureRelated {
  EventRelationshipType? get relationshipType;

  String? get relatedEventId;
}
