import 'package:tungstn/client/components/account_switch_prefix/account_switch_prefix.dart';
import 'package:tungstn/client/components/push_notification/notification_manager.dart';
import 'package:tungstn/client/room.dart';
import 'package:tungstn/client/timeline_events/timeline_event.dart';
import 'package:tungstn/client/timeline_events/timeline_event_message.dart';
import 'package:tungstn/config/layout_config.dart';
import 'package:tungstn/ui/molecules/message_input.dart';
import 'package:tungstn/ui/molecules/room_timeline_widget/room_timeline_widget.dart';
import 'package:tungstn/ui/molecules/typing_indicators_widget.dart';
import 'package:tungstn/ui/organisms/chat/chat.dart';
import 'package:tungstn/ui/organisms/particle_player/particle_player.dart';
import 'package:tungstn/utils/autofill_utils.dart';
import 'package:tungstn/utils/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatView extends StatelessWidget {
  const ChatView(this.state, {super.key});
  final ChatState state;

  String get cantSentMessagePrompt => Intl.message(
      "You do not have permission to send a message in this room",
      name: "cantSentMessagePrompt",
      desc: "Text that explains the user cannot send a message in this room");

  String? get relatedEventSenderName => state.interactingEvent == null
      ? null
      : state.room
          .getMemberOrFallback(state.interactingEvent!.senderId)
          .displayName;

  Color? get relatedEventSenderColor => state.interactingEvent == null
      ? null
      : state.room.getColorOfUser(state.interactingEvent!.senderId);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
          child: Stack(
        fit: StackFit.expand,
        children: [
          timeline(),
          const ParticlePlayer(),
          Positioned(
            top: 8,
            right: 8,
            child: _e2eeBadge(context),
          ),
        ],
      )),
      input(),
    ]);
  }

  Widget _e2eeBadge(BuildContext context) => _E2eeBadge(state.room.isE2EE);

  Widget timeline() {
    return state.timeline == null
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : RoomTimelineWidget(
            key: ValueKey("${state.room.identifier}-timeline"),
            timeline: state.timeline!,
            setReplyingEvent: (event) => state.setInteractingEvent(event,
                type: EventInteractionType.reply),
            setEditingEvent: (event) => state.setInteractingEvent(event,
                type: EventInteractionType.edit),
            isThreadTimeline: state.isThread,
            clearNotifications: clearNotifications,
          );
  }

  void handleMarkAsRead(TimelineEvent event) async {
    // Dont update read receipts if in background
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    state.room.timeline!.markAsRead(event);
  }

  void clearNotifications(Room room) {
    // if we clear notifications when opening bubble, the bubble disappears
    if (state.isBubble) {
      return;
    }

    NotificationManager.clearNotifications(room);
  }

  Widget input() {
    String? interactingEventBody = state.interactingEvent?.plainTextBody;

    if (state.interactingEvent case TimelineEventMessage m) {
      if (state.timeline != null) {
        interactingEventBody = m.getPlaintextBody(state.timeline!);
      }
    }

    return ClipRRect(
      child: MessageInput(
        client: state.room.client,
        room: state.room,
        isRoomE2EE: state.room.isE2EE,
        focusKeyboard: state.onFocusMessageInput.stream,
        attachments: state.attachments,
        interactionType: state.interactionType,
        gifComponent: state.gifs,
        onSendMessage: (message, {overrideClient}) {
          if (overrideClient != null) {
            final processedText = state.room.client
                .getComponent<AccountSwitchPrefix>()
                ?.removePrefix(message, state.room);

            if (processedText != null) {
              message = processedText;
            }
          }
          state.sendMessage(message, overrideClient: overrideClient);
          return MessageInputSendResult.success;
        },
        onTextUpdated: state.onInputTextUpdated,
        addAttachment: state.addAttachment,
        removeAttachment: state.removeAttachment,
        size: Layout.mobile ? Layout.mobileInputButtonSize : Layout.desktopInputButtonSize,
        iconScale: Layout.mobile ? 0.6 : 0.5,
        isProcessing: state.processing,
        enabled: state.room.permissions.canSendMessage,
        relatedEventBody: interactingEventBody,
        relatedEventSenderName: relatedEventSenderName,
        relatedEventSenderColor: relatedEventSenderColor,
        setInputText: state.setMessageInputText.stream,
        availibleEmoticons: state.emoticons?.availableEmoji,
        availibleStickers: state.emoticons?.availableStickers,
        sendSticker: state.sendSticker,
        sendGif: state.sendGif,
        findOverrideClient: (input) => state.room.client
            .getComponent<AccountSwitchPrefix>()
            ?.getPrefixedAccount(input, state.room)
            ?.$1,
        onTapOverrideClient: (overrideClient) {
          EventBus.openRoom
              .add((state.room.identifier, overrideClient.identifier));

          if (state.isThread) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              EventBus.openThread.add((
                overrideClient.identifier,
                state.room.identifier,
                state.threadId!
              ));
            });
          }
        },
        editLastMessage: state.editLastMessage,
        hintText: state.room.permissions.canSendMessage
            ? 'Message ${state.room.displayName}'
            : cantSentMessagePrompt,
        cancelReply: () {
          state.setInteractingEvent(null);
        },
        typingIndicatorWidget: state.typingIndicators != null
            ? TypingIndicatorsWidget(
                component: state.typingIndicators!,
                key: ValueKey(
                    "room_typing_indicators_key_${state.room.identifier}"),
              )
            : null,
        processAutofill: (text) =>
            AutofillUtils.search(text, state.room.client, room: state.room),
      ),
    );
  }
}

class _E2eeBadge extends StatefulWidget {
  const _E2eeBadge(this.isE2EE);
  final bool isE2EE;

  @override
  State<_E2eeBadge> createState() => _E2eeBadgeState();
}

class _E2eeBadgeState extends State<_E2eeBadge>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e2ee = widget.isE2EE;
    final color = e2ee ? Colors.green : Colors.grey;
    final label = e2ee ? 'E2EE Enabled' : 'E2EE Disabled';
    final bg = Theme.of(context).colorScheme.surfaceContainer.withAlpha(210);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _controller.reverse();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _fade,
                child: SizeTransition(
                  sizeFactor: _fade,
                  axis: Axis.horizontal,
                  axisAlignment: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: color),
                    ),
                  ),
                ),
              ),
              Icon(e2ee ? Icons.lock : Icons.lock_open, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
