import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/gif/gif_search_result.dart';
import 'package:tungstn/client/components/room_component.dart';
import 'package:tungstn/client/timeline_events/timeline_event.dart';

abstract class GifComponent<R extends Client, T extends Room>
    implements RoomComponent<R, T> {
  Future<GifSearchResponse> search(String query, {String? pos});

  Future<TimelineEvent?> sendGif(GifSearchResult gif, TimelineEvent? inReplyTo);

  String get searchPlaceholder;
}
