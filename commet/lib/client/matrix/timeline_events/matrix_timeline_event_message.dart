import 'dart:math';

import 'package:commet/cache/file_provider.dart';
import 'package:commet/client/attachment.dart';
import 'package:commet/main.dart' show preferences;
import 'package:http/http.dart' as http;
import 'package:commet/client/matrix/components/threads/matrix_thread_timeline.dart';
import 'package:commet/client/matrix/extensions/matrix_event_extensions.dart';
import 'package:commet/client/matrix/matrix_mxc_file_provider.dart';
import 'package:commet/client/matrix/matrix_mxc_image_provider.dart';
import 'package:commet/client/matrix/matrix_timeline.dart';
import 'package:commet/client/matrix/timeline_events/matrix_timeline_event.dart';
import 'package:commet/client/matrix/timeline_events/matrix_timeline_event_mixin_reactions.dart';
import 'package:commet/client/matrix/timeline_events/matrix_timeline_event_mixin_related.dart';
import 'package:commet/client/timeline.dart';
import 'package:commet/client/timeline_events/timeline_event_message.dart';
import 'package:commet/config/platform_utils.dart';
import 'package:commet/ui/atoms/rich_text/matrix_html_parser.dart';
import 'package:commet/utils/mime.dart';
import 'package:commet/utils/oembed.dart';
import 'package:commet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' as matrix;

import 'package:html/parser.dart' as html_parser;

class MatrixTimelineEventMessage extends MatrixTimelineEvent
    with MatrixTimelineEventRelated, MatrixTimelineEventReactions
    implements TimelineEventMessage {
  MatrixTimelineEventMessage(super.event, {required super.client}) {
    attachments = _parseAnyAttachments() ?? _parseInlineImage();
  }

  matrix.Client get mx => client.getMatrixClient();

  @override
  late List<Attachment>? attachments;

  Future<List<Attachment>?>? _pendingAttachments;

  @override
  Future<List<Attachment>?>? get pendingAttachments => _pendingAttachments;

  @override
  bool get editable => true;

  @override
  String? get body => event.plaintextBody;

  String get formattedBody =>
      event.formattedText != "" ? event.formattedText : event.plaintextBody;

  @override
  String? get bodyFormat =>
      event.content.tryGet<String>("format") ??
      "chat.commet.custom.matrix_plain";

  @override
  String get plainTextBody => event.plaintextBody;

  String _getPlaintextBody({Timeline? timeline}) {
    var e = getDisplayEvent(timeline);

    if (["m.file", "m.image", "m.video", "m.audio"].contains(e.messageType)) {
      var file = e.content["file"] is Map<String, dynamic>
          ? e.content['file'] as Map<String, dynamic>
          : null;
      if (e.content.containsKey("url") == false &&
          (file?.containsKey("url") != true)) {
        return e.plaintextBody;
      }

      if (e.content.containsKey("filename")) {
        if (e.content["filename"] == e.plaintextBody) {
          return "";
        }

        return e.plaintextBody;
      } else {
        return "";
      }
    }

    return e.plaintextBody;
  }

  String _getFormattedBody({Timeline? timeline}) {
    var e = getDisplayEvent(timeline);

    if (["m.file", "m.image", "m.video", "m.audio"].contains(e.messageType)) {
      return e.formattedText;
    }

    if (e.formattedText == "") {
      return e.plaintextBody;
    }

    return e.formattedText;
  }

  @override
  String getPlaintextBody(Timeline timeline) {
    var displayEvent = getDisplayEvent(timeline);

    return displayEvent.plaintextBody;
  }

  @override
  Widget? buildFormattedContent({Timeline? timeline}) {
    final room = client.getRoom(event.roomId!)!;

    var displayEvent = getDisplayEvent(timeline);
    bool isFormatted = displayEvent.content.tryGet<String>("format") != null;
    if (isFormatted) {
      return MatrixHtmlParser.parse(
          _getFormattedBody(timeline: timeline), client, room);
    } else {
      var plain = _getPlaintextBody(timeline: timeline);
      if (plain != "") {
        return PlaintextMessageBody(
          content: plain,
          clientIdentifier: client.identifier,
        );
      }
    }

    return null;
  }

  @override
  bool isEdited(Timeline timeline) {
    var e = event.getDisplayEvent(getTimeline(timeline)!);
    return e.eventId != event.eventId;
  }

  List<Attachment>? _parseAnyAttachments() {
    String filename = event.content.containsKey("filename")
        ? event.content["filename"] as String
        : event.body;

    if (event.hasAttachment) {
      double? width = event.attachmentWidth;
      double? height = event.attachmentHeight;

      Attachment? attachment;

      if (Mime.imageTypes.contains(event.attachmentMimetype)) {
        attachment = ImageAttachment(
            MatrixMxcImage(event.attachmentMxcUrl!, mx,
                blurhash: event.attachmentBlurhash,
                doThumbnail: event.hasThumbnail,
                doFullres: true,
                thumbnailHeight: event.thumbnailHeight != null
                    ? min(700, event.thumbnailHeight!.toInt())
                    : 700,
                // I noticed on linux, decoding really high res images would cause a flicker, so we will limit it to 1440p
                fullResHeight: PlatformUtils.isLinux
                    ? (event.attachmentHeight != null
                        ? min(1440, event.attachmentHeight!.toInt())
                        : 1440)
                    : null,
                autoLoadFullRes: !event.hasThumbnail,
                matrixEvent: event),
            MxcFileProvider(mx, event.attachmentMxcUrl!, event: event),
            mimeType: event.attachmentMimetype,
            width: width,
            fileSize: event.infoMap['size'] as int?,
            name: filename,
            height: height);
      } else if (Mime.videoTypes.contains(event.attachmentMimetype)) {
        // Only load videos if the event has finished sending, otherwise
        // matrix dart sdk gives us the video file when we ask for thumbnail
        if (event.status.isSending == false) {
          attachment = VideoAttachment(
              MxcFileProvider(mx, event.attachmentMxcUrl!, event: event),
              thumbnail: event.videoThumbnailUrl != null
                  ? MatrixMxcImage(event.videoThumbnailUrl!, mx,
                      blurhash: event.attachmentBlurhash,
                      doFullres: false,
                      autoLoadFullRes: false,
                      doThumbnail: true,
                      matrixEvent: event)
                  : null,
              name: filename,
              mimeType: event.attachmentMimetype,
              duration: event.attachmentDuration,
              width: width,
              fileSize: event.infoMap['size'] as int?,
              height: height);
        }
      } else {
        attachment = FileAttachment(
            MxcFileProvider(mx, event.attachmentMxcUrl!, event: event),
            name: filename,
            mimeType: event.attachmentMimetype,
            fileSize: event.infoMap['size'] as int?);
      }

      return List.from([attachment]);
    }

    return null;
  }

  List<Attachment>? _parseInlineImage() {
    // Commet-sent GIFs carry full metadata — always render regardless of the
    // inlineImageDetection preference (that gate is only for arbitrary URLs).
    final inlineImage =
        event.content['com.commet.inline_image'] as Map<String, dynamic>?;
    if (inlineImage != null) {
      final url = inlineImage['url'] as String?;
      final uri = url != null ? Uri.tryParse(url) : null;
      if (uri != null) {
        return [
          ImageAttachment(
            NetworkImage(url!),
            UrlFileProvider(uri),
            name: uri.pathSegments.lastOrNull ?? 'image',
            mimeType: inlineImage['mimetype'] as String?,
            width: (inlineImage['w'] as num?)?.toDouble(),
            height: (inlineImage['h'] as num?)?.toDouble(),
          )
        ];
      }
    }

    // For plain text messages that look like a bare URL, fire a HEAD request
    // to verify the MIME type. Show a shimmer placeholder in the meantime.
    if (!preferences.inlineImageDetection.value) return null;

    final room = client.getRoom(event.roomId!);
    if (room?.isE2EE == true && !preferences.urlPreviewInE2EEChat.value) {
      return null;
    }
    if (event.messageType != 'm.text') return null;

    final body = event.plaintextBody.trim();
    final uri = Uri.tryParse(body);
    if (uri == null || !uri.hasScheme) return null;

    _pendingAttachments = _resolveUrlAttachment(uri, body);
    return [PendingAttachment()];
  }

  Future<List<Attachment>?> _resolveUrlAttachment(Uri uri, String body) async {
    // Try oEmbed first for known providers (YouTube, Vimeo, SoundCloud, etc.)
    final oEmbed = await OEmbedService.fetch(uri);
    if (oEmbed != null) {
      return [
        OEmbedAttachment(
          originalUrl: body,
          title: oEmbed.title,
          authorName: oEmbed.authorName,
          thumbnailUrl: oEmbed.thumbnailUrl,
          thumbnailWidth: oEmbed.thumbnailWidth,
          thumbnailHeight: oEmbed.thumbnailHeight,
          providerName: oEmbed.providerName,
        )
      ];
    }

    // HEAD-check to confirm the URL is an image.
    bool headSucceeded = false;
    try {
      final response =
          await http.head(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        headSucceeded = true;
        final contentType = response.headers['content-type'];
        final mimeType = contentType?.split(';').first.trim().toLowerCase();
        if (mimeType != null && Mime.imageTypes.contains(mimeType)) {
          return [
            ImageAttachment(
              NetworkImage(body),
              UrlFileProvider(uri),
              name: uri.pathSegments.lastOrNull ?? 'image',
              mimeType: mimeType,
            )
          ];
        }
        return null;
      }
    } on Exception catch (_) {
      // Network errors and timeouts are expected — fall through to extension
      // detection. Non-Exception errors (e.g. assertion failures) still throw.
    }

    // If HEAD failed (server didn't respond), fall back to extension detection.
    if (!headSucceeded) {
      final ext =
          uri.pathSegments.lastOrNull?.split('.').lastOrNull?.toLowerCase();
      final mimeType = Mime.lookupType('.$ext');
      if (mimeType != null && Mime.imageTypes.contains(mimeType)) {
        return [
          ImageAttachment(
            NetworkImage(body),
            UrlFileProvider(uri),
            name: uri.pathSegments.lastOrNull ?? 'image',
            mimeType: mimeType,
          )
        ];
      }
    }

    return null;
  }

  @override
  List<Uri>? getLinks({Timeline? timeline}) {
    var text = _getFormattedBody(timeline: timeline);
    var start = text.indexOf("<mx-reply>");
    var end = text.indexOf("</mx-reply>");

    if (start != -1 && end != -1 && start < end) {
      text = text.replaceRange(start, end, "");
    }

    var foundLinks = TextUtils.findUrls(text);

    foundLinks?.removeWhere((element) => element.authority == "matrix.to");
    if (foundLinks?.isEmpty == true) {
      foundLinks = null;
    }

    return foundLinks;
  }

  matrix.Event getDisplayEvent(Timeline? tl) {
    var mx = getTimeline(tl);

    if (mx == null) return event;

    return event.getDisplayEvent(mx);
  }

  matrix.Timeline? getTimeline(Timeline? tl) {
    if (tl == null) return null;

    if (tl is MatrixThreadTimeline) {
      return tl.mainRoomTimeline.matrixTimeline;
    } else {
      return (tl as MatrixTimeline).matrixTimeline;
    }
  }
}

class PlaintextMessageBody extends StatelessWidget {
  const PlaintextMessageBody(
      {required this.content, required this.clientIdentifier, super.key});
  final String content;
  final String clientIdentifier;

  @override
  Widget build(BuildContext context) {
    var document = html_parser.parse(content);
    bool big = shouldDoBigEmoji(document);

    return Text.rich(TextSpan(
        style: TextStyle(fontSize: big ? 34 : null),
        children: TextUtils.linkifyString(content,
            context: context, clientId: clientIdentifier)));
  }
}
