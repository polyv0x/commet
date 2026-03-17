import 'package:commet/client/attachment.dart';
import 'package:commet/config/build_config.dart';
import 'package:commet/ui/atoms/hover_link.dart';
import 'package:commet/ui/atoms/lightbox.dart';
import 'package:commet/ui/atoms/pausable_animated_image.dart';
import 'package:commet/ui/molecules/audio_player/audio_player.dart';
import 'package:commet/ui/molecules/video_player/video_player.dart';
import 'package:commet/ui/molecules/video_player/video_player_controller.dart';
import 'package:commet/utils/background_tasks/background_task_manager.dart';
import 'package:commet/utils/download_utils.dart';
import 'package:commet/utils/mime.dart';
import 'package:commet/utils/links/link_utils.dart';
import 'package:commet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:tiamat/tiamat.dart' as tiamat;

class MessageAttachment extends StatefulWidget {
  const MessageAttachment(this.attachment,
      {super.key,
      this.ignorePointer = false,
      this.previewMedia = false,
      this.clientId});
  final Attachment attachment;
  final bool ignorePointer;
  final bool previewMedia;
  final String? clientId;
  @override
  State<MessageAttachment> createState() => _MessageAttachmentState();
}

class _MessageAttachmentState extends State<MessageAttachment> {
  late Key videoPlayerKey;
  bool isFullscreen = false;
  var controller = VideoPlayerController();
  @override
  void initState() {
    videoPlayerKey = GlobalKey();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachment is PendingAttachment) return const _AttachmentShimmer();
    if (widget.attachment is OEmbedAttachment) return buildOEmbed();

    if (widget.previewMedia) {
      if (widget.attachment is ImageAttachment) return buildImage();
      if (widget.attachment is VideoAttachment) {
        if (BuildConfig.WEB) {
          return buildFile(Icons.video_file, widget.attachment.name, null);
        }
        return buildVideo();
      }
    }

    final attachment = widget.attachment;
    if (attachment is FileAttachment) {
      if (attachment.mimeType != null &&
          Mime.playableAudioTypes.contains(attachment.mimeType!)) {
        return buildAudio(attachment);
      }

      return buildFile(Mime.toIcon(attachment.mimeType), attachment.name,
          attachment.fileSize);
    }

    return const Placeholder();
  }

  Widget buildImage() {
    assert(widget.attachment is ImageAttachment);
    var attachment = widget.attachment as ImageAttachment;

    return IgnorePointer(
      ignoring: widget.ignorePointer,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: 200, minHeight: 40, maxWidth: 500, minWidth: 40),
                child: InkWell(
                  onTap: fullscreenAttachment,
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    child: SizedBox(
                      width: attachment.width ?? 500,
                      height: attachment.height ?? 500,
                      child: PausableAnimatedImage(
                        image: attachment.image,
                        filterQuality: FilterQuality.medium,
                        // if we know the height, its safe to fill as it wont appear stretched
                        fit: attachment.width != null &&
                                attachment.height != null
                            ? BoxFit.fill
                            : BoxFit.fitWidth,
                      ),
                    ),
                  ),
                ),
              ))),
    );
  }

  Widget buildVideo() {
    var attachment = widget.attachment as VideoAttachment;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 200 + 30,
        width: attachment.aspectRatio * 200,
        child: tiamat.Panel(
            mainAxisSize: MainAxisSize.min,
            header:
                "${attachment.name} ${attachment.fileSize != null ? "- ${TextUtils.readableFileSize(attachment.fileSize!)}" : ""}",
            mode: tiamat.TileType.surfaceContainerLow,
            padding: 0,
            child: SizedBox(
                height: 200,
                width: 500,
                child: AspectRatio(
                    aspectRatio: attachment.aspectRatio,
                    child: isFullscreen
                        ? null
                        : VideoPlayer(
                            attachment.file,
                            thumbnail: attachment.thumbnail,
                            fileName: attachment.name,
                            doThumbnail: true,
                            canGoFullscreen: true,
                            onFullscreen: fullscreenVideo,
                            controller: controller,
                            key: videoPlayerKey,
                          )))),
      ),
    );
  }

  void fullscreenAttachment() {
    if (widget.attachment is ImageAttachment) {
      final attachment = widget.attachment as ImageAttachment;
      Lightbox.show(context, image: attachment.image);
    }

    if (widget.attachment is VideoAttachment) {
      fullscreenVideo();
    }
  }

  void fullscreenVideo() {
    var attachment = (widget.attachment as VideoAttachment);
    setState(() {
      isFullscreen = true;
    });
    Lightbox.show(context,
            video: attachment.file,
            aspectRatio: attachment.aspectRatio,
            thumbnail: attachment.thumbnail,
            videoController: controller,
            key: videoPlayerKey)
        .then((value) {
      setState(() {
        isFullscreen = false;
      });
    });
  }

  Widget buildFile(IconData icon, String fileName, int? fileSize) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(icon),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tiamat.Text.labelEmphasised(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (fileSize != null)
                          tiamat.Text.labelLow(
                              TextUtils.readableFileSize(fileSize))
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.attachment is ImageAttachment ||
                widget.attachment is VideoAttachment)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: tiamat.IconButton(
                  size: 20,
                  icon: Icons.visibility,
                  onPressed: fullscreenAttachment,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: tiamat.IconButton(
                    size: 20,
                    icon: Icons.download,
                    onPressed: () async {
                      if (widget.attachment is FileAttachment) {
                        downloadAttachment(widget.attachment as FileAttachment);
                      }
                    },
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Future<void> downloadAttachment(FileAttachment attachment) async {
    return DownloadUtils.downloadAttachment(attachment);
  }

  Future<BackgroundTaskStatus> downloadTask(
      FileAttachment attachment, String path) async {
    await attachment.file.save(path);

    return BackgroundTaskStatus.completed;
  }

  Widget buildOEmbed() {
    final attachment = widget.attachment as OEmbedAttachment;
    final uri = Uri.tryParse(attachment.originalUrl);
    final onTap = uri != null
        ? () => LinkUtils.open(uri, clientId: widget.clientId, context: context)
        : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachment.thumbnailUrl != null)
                MouseRegion(
                  cursor: uri != null
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  child: GestureDetector(
                    onTap: onTap,
                    child: AspectRatio(
                      aspectRatio: attachment.thumbnailWidth != null &&
                              attachment.thumbnailHeight != null
                          ? attachment.thumbnailWidth! /
                              attachment.thumbnailHeight!
                          : 16 / 9,
                      child: Image.network(
                        attachment.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (attachment.providerName != null) ...[
                      tiamat.Text.labelLow(attachment.providerName!),
                      const SizedBox(height: 2),
                    ],
                    if (attachment.title != null)
                      LinkText(
                        attachment.title!,
                        uri: uri,
                        clientId: widget.clientId,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge!
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    if (attachment.authorName != null) ...[
                      const SizedBox(height: 2),
                      tiamat.Text.labelLow(
                        attachment.authorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAudio(FileAttachment attachment) {
    return AudioPlayer(
      file: attachment.file,
      fileName: attachment.name,
      fileSize: attachment.fileSize,
    );
  }
}

class _AttachmentShimmer extends StatefulWidget {
  const _AttachmentShimmer();

  @override
  State<_AttachmentShimmer> createState() => _AttachmentShimmerState();
}

class _AttachmentShimmerState extends State<_AttachmentShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => Opacity(
        opacity: _opacity.value,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 200,
            height: 120,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
        ),
      ),
    );
  }
}
