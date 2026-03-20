import 'package:tungstn/client/timeline.dart';
import 'package:tungstn/client/timeline_events/timeline_event.dart';
import 'package:flutter/material.dart';

abstract class TimelineEventGeneric extends TimelineEvent {
  String getBody({Timeline? timeline});

  IconData? get icon;

  bool get showSenderAvatar;
}
