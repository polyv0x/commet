import 'package:tungstn/client/attachment.dart';
import 'package:tungstn/client/timeline.dart';
import 'package:tungstn/client/timeline_events/timeline_event.dart';
import 'package:flutter/material.dart';

abstract class TimelineEventMessage extends TimelineEvent {
  String getPlaintextBody(Timeline timeline);

  Widget? buildFormattedContent({Timeline? timeline});
  String? get body;
  String? get bodyFormat;
  String? get formattedBody;

  List<Attachment>? get attachments;

  /// A future that resolves once async attachment detection (e.g. HEAD request)
  /// completes. Null if no async resolution is needed.
  Future<List<Attachment>?>? get pendingAttachments => null;

  bool isEdited(Timeline timeline);

  List<Uri>? getLinks({Timeline? timeline});
}
