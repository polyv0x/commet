import 'dart:convert';

import 'package:commet/client/components/gif/gif_component.dart';
import 'package:commet/client/components/gif/gif_search_result.dart';
import 'package:commet/client/matrix/matrix_client.dart';
import 'package:commet/client/matrix/matrix_room.dart';
import 'package:commet/client/matrix/matrix_timeline.dart';
import 'package:commet/client/timeline_events/timeline_event.dart';
import 'package:commet/main.dart';
import 'package:http/http.dart' as http;

import 'package:matrix/matrix.dart' as matrix;

class MatrixGifComponent implements GifComponent<MatrixClient, MatrixRoom> {
  @override
  MatrixClient client;

  @override
  MatrixRoom room;

  MatrixGifComponent(this.client, this.room);

  @override
  String get searchPlaceholder {
    if (preferences.gifSearchUrl.value != null) return "Search GIFs";
    return "Search Tenor";
  }

  @override
  Future<GifSearchResponse> search(String query, {String? pos}) async {
    final customUrl = preferences.gifSearchUrl.value;

    if (customUrl != null && customUrl.isNotEmpty) {
      var params = <String, String>{"q": query};
      if (pos != null && pos.isNotEmpty) params["pos"] = pos;

      var uri = Uri.parse("${customUrl.trimRight()}/api/v2/search")
          .replace(queryParameters: params);

      var result = await http.get(uri);
      if (result.statusCode == 200) {
        var data = jsonDecode(result.body) as Map<String, dynamic>;
        var results = (data['results'] as List?)
                ?.map((e) => parseTenorResult(e, useProxy: false))
                .toList() ??
            [];
        var next = data['next'] as String?;
        return GifSearchResponse(results, next);
      }
      return GifSearchResponse([], null);
    }

    // The ui should never actually let the user search if this is disabled, so this *shouldn't* be neccessary
    // but just to be safe!
    if (!preferences.tenorGifSearchEnabled.value)
      return GifSearchResponse([], null);

    var params = <String, String>{"q": query};
    if (pos != null && pos.isNotEmpty) params["pos"] = pos;

    var uri = Uri.https(
        preferences.proxyUrl.value, "/proxy/tenor/api/v2/search", params);

    var result = await http.get(uri);
    if (result.statusCode == 200) {
      var data = jsonDecode(result.body) as Map<String, dynamic>;
      var results = (data['results'] as List?)
              ?.map((e) => parseTenorResult(e))
              .toList() ??
          [];
      var next = data['next'] as String?;
      return GifSearchResponse(results, next);
    }

    return GifSearchResponse([], null);
  }

  @override
  Future<TimelineEvent?> sendGif(
      GifSearchResult gif, TimelineEvent? inReplyTo) async {
    final customUrl = preferences.gifSearchUrl.value;
    if (customUrl != null && customUrl.isNotEmpty) {
      return _sendGifEmbed(gif, inReplyTo);
    }
    return _sendGifUploaded(gif, inReplyTo);
  }

  /// Sends the GIF as a plain m.text message containing the source URL.
  /// A com.commet.inline_image field carries the dimensions and mime type so
  /// Commet can render it inline without a HEAD request. Other clients see a
  /// plain URL link — fully spec-compliant.
  Future<TimelineEvent?> _sendGifEmbed(
      GifSearchResult gif, TimelineEvent? inReplyTo) async {
    var matrixRoom = room.matrixRoom;
    matrix.Event? replyingTo;
    if (inReplyTo != null) {
      replyingTo = await matrixRoom.getEventById(inReplyTo.eventId);
    }

    var content = {
      "msgtype": "m.text",
      "body": gif.fullResUrl.toString(),
      "com.commet.inline_image": {
        "url": gif.fullResUrl.toString(),
        "mimetype": gif.mimeType,
        "w": gif.x.toInt(),
        "h": gif.y.toInt(),
      }
    };

    var id = await matrixRoom.sendEvent(content,
        type: matrix.EventTypes.Message,
        inReplyTo: replyingTo);

    if (id != null) {
      var event = await matrixRoom.getEventById(id);
      return room.convertEvent(event!,
          timeline: (room.timeline as MatrixTimeline).matrixTimeline);
    }
    return null;
  }

  Future<TimelineEvent?> _sendGifUploaded(
      GifSearchResult gif, TimelineEvent? inReplyTo) async {
    var matrixRoom = room.matrixRoom;
    var response = await matrixRoom.client.httpClient.get(gif.fullResUrl);
    if (response.statusCode == 200) {
      var data = response.bodyBytes;

      matrix.Event? replyingTo;
      var uri = await matrixRoom.client
          .uploadContent(data, filename: "sticker", contentType: gif.mimeType);

      var content = {
        "body": gif.fullResUrl.pathSegments.last,
        "url": uri.toString(),
        if (preferences.stickerCompatibilityMode.value) "msgtype": "m.image",
        if (preferences.stickerCompatibilityMode.value)
          "chat.commet.type": "chat.commet.sticker",
        "info": {
          "chat.commet.animated": true,
          "w": gif.x.toInt(),
          "h": gif.y.toInt(),
          "mimetype": gif.mimeType
        }
      };

      if (inReplyTo != null) {
        replyingTo = await matrixRoom.getEventById(inReplyTo.eventId);
      }

      var id = await matrixRoom.sendEvent(content,
          type: preferences.stickerCompatibilityMode.value
              ? matrix.EventTypes.Message
              : matrix.EventTypes.Sticker,
          inReplyTo: replyingTo);

      if (id != null) {
        var event = await matrixRoom.getEventById(id);
        return room.convertEvent(event!,
            timeline: (room.timeline as MatrixTimeline).matrixTimeline);
      }
    }

    return null;
  }

  GifSearchResult parseTenorResult(Map<String, dynamic> result,
      {bool useProxy = true}) {
    const int sizeLimit = 3000000; //3 MB

    var formats = result['media_formats'] as Map<String, dynamic>;

    String mimeType = "image/gif";

    var preview =
        formats['tinygif'] ?? formats['nanogif'] ?? formats['mediumgif'];

    var fullRes = formats['gif'];

    //We only want to send full res if less than 3mb
    if (fullRes['size'] as int > sizeLimit && formats['mediumgif'] != null) {
      fullRes = formats['mediumgif'];
    }

    if (formats["webp"]['size'] < fullRes['size']) {
      fullRes = formats["webp"];
      mimeType = "image/webp";
    }

    if (formats["webp"]['size'] < preview['size']) {
      preview = formats["webp"];
    }

    List<dynamic> dimensions = fullRes['dims']! as List<dynamic>;

    return GifSearchResult(
        useProxy ? convertUrl(preview['url']) : Uri.parse(preview['url']),
        useProxy ? convertUrl(fullRes['url']) : Uri.parse(fullRes['url']),
        (dimensions[0] as int).roundToDouble(),
        (dimensions[1] as int).roundToDouble(),
        mimeType);
  }

  Uri convertUrl(String url) {
    var uri = Uri.parse(url);

    var proxyUri =
        Uri.https(preferences.proxyUrl.value, "/proxy/tenor/media${uri.path}");

    return proxyUri;
  }
}
