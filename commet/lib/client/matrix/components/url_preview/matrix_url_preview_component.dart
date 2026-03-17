import 'package:commet/client/components/url_preview/url_preview_component.dart';
import 'package:commet/client/matrix/matrix_client.dart';
import 'package:commet/client/matrix/matrix_mxc_image_provider.dart';
import 'package:commet/client/matrix/matrix_room.dart';
import 'package:commet/client/room.dart';
import 'package:commet/client/timeline.dart';
import 'package:commet/client/timeline_events/timeline_event.dart';
import 'package:commet/client/timeline_events/timeline_event_message.dart';
import 'package:commet/debug/log.dart';
import 'package:commet/main.dart';
import 'package:commet/utils/mime.dart';
import 'package:commet/utils/oembed.dart';
import 'package:flutter/widgets.dart';
import 'package:matrix/matrix.dart' as matrix;
import 'package:matrix/matrix_api_lite.dart';

class MatrixUrlPreviewComponent implements UrlPreviewComponent<MatrixClient> {
  @override
  MatrixClient client;

  Map<String, UrlPreviewData> cache = {};

  bool? serverSupportsUrlPreview;

  MatrixUrlPreviewComponent(this.client) {
    _probeServerSupport();
  }

  // Fire a lightweight probe at construction time so serverSupportsUrlPreview
  // is set before any timeline messages render, avoiding a burst of redundant
  // requests while the flag is still null.
  Future<void> _probeServerSupport() async {
    final mxClient = client.getMatrixClient();
    for (final path in await getRequestPaths()) {
      try {
        await mxClient.request(
          matrix.RequestType.GET,
          path,
          query: {'url': mxClient.homeserver.toString()},
        );
        serverSupportsUrlPreview = true;
        return;
      } catch (e) {
        if (e is MatrixException && e.error == MatrixError.M_UNRECOGNIZED) {
          continue;
        }
        // Network errors etc. — don't assume unsupported.
        serverSupportsUrlPreview = true;
        return;
      }
    }
    serverSupportsUrlPreview = false;
  }

  @override
  Future<UrlPreviewData?> getPreview(
      Timeline timeline, TimelineEvent event) async {
    if (event is! TimelineEventMessage) {
      return null;
    }

    final room = timeline.room;

    if (room.isE2EE && preferences.urlPreviewInE2EEChat.value == false) {
      Log.i(
          "Not getting url preview because chat is encrypted and its not enabled");
      return null;
    }

    var mxClient = (room as MatrixRoom).matrixRoom.client;

    var uri = event.getLinks(timeline: timeline)!.first;

    if (cache.containsKey(uri.toString())) {
      return cache[uri.toString()];
    }

    UrlPreviewData? data;

    if (serverSupportsUrlPreview != false) {
      try {
        data = await fetchPreviewData(mxClient, uri);
      } catch (_) {
        // Fall through to oEmbed fallback.
      }
    }

    // Treat empty server responses (no title/description/image) the same as
    // null — the homeserver reached the endpoint but got nothing useful
    // (e.g. YouTube blocks homeserver IPs).
    final isEmpty = data != null &&
        data.title == null &&
        data.description == null &&
        data.image == null;

    // Try client-side oEmbed when server returned nothing useful.
    if (data == null || isEmpty) {
      data = await _fetchOEmbedFallback(uri);
    }

    if (data != null) {
      cache[uri.toString()] = data;
    } else {
      cache[uri.toString()] = UrlPreviewComponent.invalidPreviewData;
    }

    return data;
  }

  @override
  UrlPreviewData? getCachedPreview(Timeline timeline, TimelineEvent event) {
    if (event is! TimelineEventMessage) {
      return null;
    }

    var uri = event.getLinks(timeline: timeline)?.firstOrNull;

    if (uri == null) {
      return null;
    }

    if (cache.containsKey(uri.toString())) {
      return cache[uri.toString()];
    }

    return null;
  }

  @override
  bool shouldGetPreviewsInRoom(Room room) {
    if (room.isE2EE && preferences.urlPreviewInE2EEChat.value == false) {
      return false;
    }

    if (serverSupportsUrlPreview == false) {
      return false;
    }

    return true;
  }

  @override
  bool shouldGetPreviewDataForTimelineEvent(
      Timeline timeline, TimelineEvent event) {
    if (event is! TimelineEventMessage) {
      return false;
    }

    final room = timeline.room;

    if (!shouldGetPreviewsInRoom(room)) {
      return false;
    }

    final links = event.getLinks(timeline: timeline);

    return links?.isNotEmpty == true;
  }

  Future<List<String>> getRequestPaths() async {
    if (await client.getMatrixClient().authenticatedMediaSupported()) {
      if (preferences.allowUnauthenticatedUrlPreview.value) {
        return ['/client/v1/media/preview_url', '/media/v3/preview_url'];
      }
      return ['/client/v1/media/preview_url'];
    }
    return ['/media/v3/preview_url'];
  }

  @override
  Future<UrlPreviewData?> getPreviewForUrl(Room room, Uri uri) async {
    if (shouldGetPreviewsInRoom(room) == false) {
      return null;
    }

    if (uri.authority == "matrix.to") {
      return null;
    }

    if (cache.containsKey(uri.toString())) {
      return cache[uri.toString()];
    }

    UrlPreviewData? data;

    try {
      data =
          await fetchPreviewData((room as MatrixRoom).matrixRoom.client, uri);
    } catch (_) {
      return null;
    }

    if (data != null) {
      cache[uri.toString()] = data;
    }

    return data;
  }

  Future<UrlPreviewData?> _fetchOEmbedFallback(Uri uri) async {
    final result = await OEmbedService.fetch(uri);
    if (result == null) return null;
    ImageProvider? thumbnail;
    if (result.thumbnailUrl != null) {
      thumbnail = NetworkImage(result.thumbnailUrl!);
    }
    return UrlPreviewData(
      uri,
      title: result.title,
      siteName: result.providerName,
      image: thumbnail,
    );
  }

  Future<UrlPreviewData?> fetchPreviewData(
      matrix.Client client, Uri url) async {
    late Map<String, Object?> response;
    final paths = await getRequestPaths();
    Object? lastError;
    StackTrace? lastStack;
    for (final path in paths) {
      try {
        response = await client.request(
            matrix.RequestType.GET, path,
            query: {"url": url.toString()});
        lastError = null;
        break;
      } catch (e, s) {
        lastError = e;
        lastStack = s;
        if (e is MatrixException && e.error == MatrixError.M_UNRECOGNIZED) {
          continue; // try the next path
        }
        Log.onError(e, s);
        return null;
      }
    }

    if (lastError != null) {
      serverSupportsUrlPreview = false;
      // M_UNRECOGNIZED means the server doesn't support this endpoint — not
      // worth logging as an error.
      final isUnrecognized = lastError is MatrixException &&
          lastError.error == MatrixError.M_UNRECOGNIZED;
      if (!isUnrecognized) {
        Log.onError(lastError, lastStack!);
      }
      return null;
    }

    serverSupportsUrlPreview = true;
    var title = response['og:title'] as String?;
    var siteName = response['og:site_name'] as String?;
    var imageUrl = response['og:image'] as String?;
    var description = response['og:description'] as String?;

    var type = response["og:image:type"] as String?;
    if (type != null) {
      if (Mime.displayableImageTypes.contains(type) == false) {
        imageUrl = null;
      }
    }

    ImageProvider? image;
    if (imageUrl != null) {
      var imageUri = Uri.parse(imageUrl);
      if (imageUri.scheme == "mxc") {
        try {
          image = MatrixMxcImage(imageUri, client, doThumbnail: false);
        } catch (exception, stack) {
          Log.onError(exception, stack);
          Log.w("Failed to get mxc image");
        }
      }
    }

    if (description != null) {
      description = description.replaceAll("\n", "    ");
    }

    return UrlPreviewData(url,
        siteName: siteName,
        title: title,
        image: image,
        description: description);
  }
}
