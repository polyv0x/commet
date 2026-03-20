import 'package:tungstn/client/attachment.dart';
import 'package:tungstn/client/timeline.dart';

abstract class Photo {
  Attachment? get attachment;

  TimelineEventStatus get status;

  String get id;

  double? get width;
  double? get height;
}
