import 'package:tungstn/config/layout_config.dart';
import 'package:tungstn/main.dart';
import 'package:tungstn/ui/pages/settings/categories/app/boolean_toggle.dart';
import 'package:tungstn/ui/pages/setup/menus/check_for_updates.dart';
import 'package:tungstn/utils/update_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:tiamat/tiamat.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => GeneralSettingsPageState();
}

class GeneralSettingsPageState extends State<GeneralSettingsPage> {
  late TextEditingController _gifSearchUrlController;

  @override
  void dispose() {
    _gifSearchUrlController.dispose();
    super.dispose();
  }
  String get labelThirdPartyServicesTitle =>
      Intl.message("Third party services",
          desc: "Header for the third party services section in settings",
          name: "labelThirdPartyServicesTitle");

  String get labelGifSearchToggle => Intl.message("Gif search",
      desc: "Label for the toggle for enabling and disabling gif search",
      name: "labelGifSearchToggle");

  String labelGifSearchDescription(proxyUrl) => Intl.message(
      "Enable use of Tenor gif search. Requests will be proxied via $proxyUrl",
      desc: "Explains that gifs will be fetched via proxy",
      args: [proxyUrl],
      name: "labelGifSearchDescription");

  String get labelInlineImageDetectionTitle =>
      Intl.message("Inline image detection",
          desc: "Label for the toggle that controls inline image detection",
          name: "labelInlineImageDetectionTitle");

  String get labelInlineImageDetectionDescription => Intl.message(
      "Detect image URLs in messages and render them inline. May send a HEAD request per link to check the content type.",
      desc: "Description for the inline image detection setting",
      name: "labelInlineImageDetectionDescription");

  String get labelUrlPreviewInEncryptedChatTitle => Intl.message(
      "URL Preview in Encrypted Chats",
      desc:
          "Label for the toggle for enabling and disabling use of url previews in encrypted chats",
      name: "labelUrlPreviewInEncryptedChatTitle");

  String get labelUrlPreviewInEncryptedChatDescription => Intl.message(
      "This will expose any URLs sent in your encrypted chats to your homeserver in order to fetch the preview",
      desc:
          "description for the toggle for enabling and disabling use of url previews in encrypted chats",
      name: "labelUrlPreviewInEncryptedChatDescription");

  String get labelAllowUnauthenticatedUrlPreviewTitle => Intl.message(
      "Allow Unauthenticated URL Preview",
      desc: "Label for the toggle to allow unauthenticated URL preview requests",
      name: "labelAllowUnauthenticatedUrlPreviewTitle");

  String get labelAllowUnauthenticatedUrlPreviewDescription => Intl.message(
      "Fall back to the unauthenticated URL preview endpoint if the authenticated one is unavailable. Less secure — only enable if previews are not working.",
      desc:
          "Description for the toggle to allow unauthenticated URL preview requests",
      name: "labelAllowUnauthenticatedUrlPreviewDescription");

  String get labelAppBehaviourTitle => Intl.message("App Behaviour",
      desc: "Header for the app behaviour section in settings",
      name: "labelAppBehaviourTitle");

  String get labelAskBeforeDeletingMessageToggle => Intl.message(
      "Ask before deleting messages",
      desc:
          "Label for the toggle for enabling and disabling message deletion confirmation",
      name: "labelAskBeforeDeletingMessageToggle");

  String get labelAskBeforeDeletingMessageDescription => Intl.message(
      "Enables the pop-up asking for confirmation when deleting a message.",
      desc:
          "Label describing what 'asking before deleting messages' even means",
      name: "labelAskBeforeDeletingMessageDescription");

  String get labelMessageEffectsTitle => Intl.message("Message Effects",
      desc:
          "Header for the settings tile for message effects, such as confetti",
      name: "labelMessageEffectsTitle");

  String get labelMessageEffectsDescription => Intl.message(
      "Messages can be sent with additional effects, such as confetti",
      desc: "Label describing what message effects are",
      name: "labelMessageEffectsDescription");

  String get labelMediaPreviewSettingsTitle => Intl.message("Media Preview",
      desc: "Header for the settings tile for for media preview toggles",
      name: "labelMediaPreviewSettingsTitle");

  String get labelMediaSettings => Intl.message("Media",
      desc: "Header for the settings tile for for media",
      name: "labelMediaSettings");

  String get labelMediaPreviewPrivateRoomsToggle => Intl.message(
        "Private Rooms",
        desc:
            "Short label for the private rooms toggle in media previews section",
        name: "labelMediaPreviewPrivateRoomsToggle",
      );

  String get labelMediaPreviewPrivateRoomsToggleDescription => Intl.message(
      "Toggle previewing of images, videos, stickers and urls in private chats",
      desc: "Label describing toggle of media previews for private rooms",
      name: "labelMediaPreviewPrivateRoomsToggleDescription");

  String get labelMediaPreviewPublicRoomsToggle => Intl.message(
        "Public Rooms",
        desc:
            "Short label for the private rooms toggle in media previews section",
        name: "labelMediaPreviewPublicRoomsToggle",
      );

  String get labelMediaPreviewPublicRoomsToggleDescription => Intl.message(
      "Toggle previewing of images, videos, stickers and urls in public chat rooms",
      desc: "Label describing toggle of media previews for public rooms",
      name: "labelMediaPreviewPublicRoomsToggleDescription");

  @override
  void initState() {
    _gifSearchUrlController = TextEditingController(
        text: preferences.gifSearchUrl.value ?? "");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Panel(
          header: labelThirdPartyServicesTitle,
          mode: TileType.surfaceContainerLow,
          child: Column(children: [
            BooleanPreferenceToggle(
              preference: preferences.tenorGifSearchEnabled,
              title: labelGifSearchToggle,
              description:
                  labelGifSearchDescription(preferences.proxyUrl.value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextInput(
                    label: "Custom GIF Search URL",
                    placeholder: "https://example.com",
                    controller: _gifSearchUrlController,
                    onChanged: (value) {
                      preferences.gifSearchUrl.set(
                          value.isEmpty ? null : value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            BooleanPreferenceToggle(
              preference: preferences.urlPreviewInE2EEChat,
              title: labelUrlPreviewInEncryptedChatTitle,
              description: labelUrlPreviewInEncryptedChatDescription,
            ),
            BooleanPreferenceToggle(
              preference: preferences.allowUnauthenticatedUrlPreview,
              title: labelAllowUnauthenticatedUrlPreviewTitle,
              description: labelAllowUnauthenticatedUrlPreviewDescription,
            ),
            if (UpdateChecker.shouldCheckForUpdates)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: CheckForUpdatesSettingWidget(),
              ),
          ]),
        ),
        const SizedBox(
          height: 10,
        ),
        Panel(
          header: labelAppBehaviourTitle,
          mode: TileType.surfaceContainerLow,
          child: Column(children: [
            BooleanPreferenceToggle(
              preference: preferences.askBeforeDeletingMessageEnabled,
              title: labelAskBeforeDeletingMessageToggle,
              description: labelAskBeforeDeletingMessageDescription,
            ),
            BooleanPreferenceToggle(
              preference: preferences.autoFocusMessageTextBox,
              title: "Autofocus Message Input",
              description:
                  "Automatically focus on the message input text field when opening a chat",
            ),
            BooleanPreferenceToggle(
              preference: preferences.automaticallyOpenSpace,
              title: "Always open space",
              description:
                  "When navigating to a room from outside of a space, also open the space the room is in, if any",
            )
          ]),
        ),
        const SizedBox(
          height: 10,
        ),
        Panel(
          header: labelMessageEffectsTitle,
          mode: TileType.surfaceContainerLow,
          child: BooleanPreferenceToggle(
            preference: preferences.messageEffectsEnabled,
            title: labelMessageEffectsTitle,
            description: labelMessageEffectsDescription,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Panel(
          header: labelMediaSettings,
          mode: TileType.surfaceContainerLow,
          child: Column(children: [
            BooleanPreferenceToggle(
              preference: preferences.inlineImageDetection,
              title: labelInlineImageDetectionTitle,
              description: labelInlineImageDetectionDescription,
            ),
            BooleanPreferenceToggle(
              preference: preferences.previewMediaInPrivateRooms,
              title: labelMediaPreviewPrivateRoomsToggle,
              description: labelMediaPreviewPrivateRoomsToggleDescription,
            ),
            BooleanPreferenceToggle(
              preference: preferences.previewMediaInPublicRooms,
              title: labelMediaPreviewPublicRoomsToggle,
              description: labelMediaPreviewPublicRoomsToggleDescription,
            ),
            if (Layout.mobile) ...[
              Seperator(),
              BooleanPreferenceToggle(
                preference: preferences.autoRotateImages,
                title: "Rotate Images",
                description:
                    "When showing images in fullscreen, automatically rotate the image to best fill the screen",
              ),
              BooleanPreferenceToggle(
                preference: preferences.autoRotateVideos,
                title: "Rotate Videos",
                description:
                    "When showing videos in fullscreen, automatically rotate the video to best fill the screen",
              ),
            ]
          ]),
        ),
      ],
    );
  }
}
