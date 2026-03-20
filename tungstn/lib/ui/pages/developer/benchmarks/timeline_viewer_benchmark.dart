import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/matrix/components/profile/matrix_profile_component.dart';
import 'package:tungstn/client/matrix/matrix_client.dart';
import 'package:tungstn/diagnostic/mocks/matrix_client_component_mocks.dart';
import 'package:tungstn/ui/molecules/room_timeline_widget/room_timeline_widget_view.dart';
import 'package:tungstn/ui/pages/developer/benchmarks/benchmark_utils.dart';
import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart' as matrix;

class BenchmarkTimelineViewer extends StatefulWidget {
  const BenchmarkTimelineViewer({super.key});

  @override
  State<BenchmarkTimelineViewer> createState() =>
      _BenchmarkTimelineViewerState();
}

class _BenchmarkTimelineViewerState extends State<BenchmarkTimelineViewer> {
  Timeline? timeline;

  @override
  void initState() {
    MatrixClient.create("benchmark").then((client) {
      client.mockComponents();
      client.self = MatrixProfile(client,
          matrix.Profile(userId: '@benchy:matrix.org', displayName: 'benchy'));

      var room = client.createRoomWithData();
      timeline = room.getBenchmarkTimeline();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.chevron_left),
      ),
      body: timeline != null
          ? RoomTimelineWidgetView(
              key: const ValueKey("timeline-viewer-benchmark"),
              timeline: timeline!,
              // doMessageOverlayMenu: false,
            )
          : Container(),
    );
  }
}
