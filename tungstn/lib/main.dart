import 'dart:async';
import 'dart:io';

import 'package:tungstn/cache/file_cache.dart';
import 'package:tungstn/client/client_manager.dart';
import 'package:tungstn/client/components/component.dart';
import 'package:tungstn/client/components/push_notification/android/unified_push_notifier.dart';
import 'package:tungstn/client/components/push_notification/notification_manager.dart';
import 'package:tungstn/config/build_config.dart';
import 'package:tungstn/config/global_config.dart';
import 'package:tungstn/config/layout_config.dart';
import 'package:tungstn/config/platform_utils.dart';
import 'package:tungstn/config/preferences.dart';
import 'package:tungstn/debug/log.dart';
import 'package:tungstn/diagnostic/diagnostics.dart';
import 'package:tungstn/generated/intl/messages_all.dart';
import 'package:tungstn/single_instance.dart';
import 'package:tungstn/ui/pages/bubble/bubble_page.dart';
import 'package:tungstn/ui/pages/fatal_error/fatal_error_page.dart';
import 'package:tungstn/ui/pages/login/login_page.dart';
import 'package:tungstn/ui/pages/main/main_page.dart';
import 'package:tungstn/ui/pages/setup/menus/check_for_updates.dart';
import 'package:tungstn/utils/android_intent_helper.dart';
import 'package:tungstn/utils/custom_safe_area.dart';
import 'package:tungstn/utils/custom_uri.dart';
import 'package:tungstn/utils/background_tasks/background_task_manager.dart';
import 'package:tungstn/utils/database/database_server.dart';
import 'package:tungstn/utils/emoji/unicode_emoji.dart';
import 'package:tungstn/utils/event_bus.dart';
import 'package:tungstn/utils/first_time_setup.dart';
import 'package:tungstn/utils/focus_node_monitor.dart';
import 'package:tungstn/utils/scaled_app.dart';
import 'package:tungstn/utils/shortcuts_manager.dart';
import 'package:tungstn/utils/system_wide_shortcuts/system_wide_shortcuts.dart';
import 'package:tungstn/utils/text_scale_changer.dart';
import 'package:tungstn/utils/update_checker.dart';
import 'package:tungstn/utils/window_management.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tiamat/config/style/theme_changer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tiamat/config/style/theme_dark.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

final GlobalKey<NavigatorState> navigator = GlobalKey();
FileCache? fileCache;
Preferences preferences = Preferences();
ShortcutsManager shortcutsManager = ShortcutsManager();
BackgroundTaskManager backgroundTaskManager = BackgroundTaskManager();
ClientManager? clientManager;

bool isHeadless = false;

Future<void>? loading;

List<String> commandLineArgs = [];

@pragma('vm:entry-point')
void unifiedPushEntry() async {
  isHeadless = true;
  Log.prefix = "unified-push";
  await WidgetsFlutterBinding.ensureInitialized();
  await preferences.init();
  await UnifiedPushNotifier().init();
}

@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse details) {
  print("Got a background notification response: $details");
}

@pragma('vm:entry-point')
void bubble() async {
  Log.prefix = "bubble";
  ensureBindingInit();
  await initNecessary();
  await initGuiRequirements();

  String? initialRoomId;
  String? initialClientId;

  var intent = await ReceiveIntent.getInitialIntent();

  if (intent?.extra?.containsKey("bubbleExtra") == true) {
    var uri = CustomURI.parse(intent!.extra!["bubbleExtra"]);

    if (uri is OpenRoomURI) {
      initialClientId = uri.clientId;
      initialRoomId = uri.roomId;
    }
  }

  Log.prefix = "bubble-$initialRoomId";

  var initialTheme = await preferences.resolveTheme();

  runApp(MaterialApp(
      title: 'Tungstn',
      theme: initialTheme,
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Provider<ClientManager>(
            create: (context) => clientManager!,
            child: child,
          ),
      home: BubblePage(
        clientManager!,
        initialClientId: initialClientId,
        initialRoom: initialRoomId,
      )));
}

void main(List<String> args) async {
  commandLineArgs = args;
  print(args);

  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  if (BuildConfig.RELEASE) {
    runZonedGuarded(appMain, Log.onError, zoneSpecification: Log.spec);
  } else {
    appMain();
  }
}

void appMain() async {
  Log.prefix = "main";
  try {
    if (BuildConfig.WEB) {
      var info = await DeviceInfoPlugin().deviceInfo;
      if (info is WebBrowserInfo) {
        Layout.browserInfo = info;
      }
    }

    ensureBindingInit();

    if (PlatformUtils.isLinux || PlatformUtils.isWindows) {
      if (await SingleInstance.tryConnectToMainInstance(commandLineArgs)) {
        exit(0);
      } else {
        SingleInstance.becomeMainInstance();
      }
    }

    FlutterError.onError = Log.getFlutterErrorReporter(FlutterError.onError);

    isHeadless = PlatformUtils.isAndroid &&
        AppLifecycleState.detached == WidgetsBinding.instance.lifecycleState;

    loading = initNecessary();

    if (isHeadless) {
      WidgetsBinding.instance.addObserver(AppStarter());
      await loading;
      return;
    } else {
      await loading;
    }

    SystemWideShortcuts.init();

    await startGui();
  } catch (error, stacktrace) {
    runApp(FatalErrorPage(error, stacktrace));
  }
}

WidgetsBinding ensureBindingInit() {
  ScaledWidgetsFlutterBinding.ensureInitialized(
    scaleFactor: (deviceSize) {
      return 1;
    },
  );

  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Cap the image cache at 100 entries (default 1000). Each animated GIF codec
  // holds its compressed data in memory; without sizeBytes tracking, the cache
  // uses only the entry count to decide when to evict. 100 is enough for a
  // visible timeline plus scroll buffer while preventing unbounded accumulation.
  PaintingBinding.instance.imageCache.maximumSize = 100;

  return binding;
}

/// Initializes the bare necessities for the app to run in headless mode
Future<void> initNecessary() async {
  sqfliteFfiInit();
  await preferences.init();
  await initDatabaseServer();

  fileCache = FileCache.getFileCacheInstance();

  await Future.wait([
    if (fileCache != null) fileCache!.init(),
    GlobalConfig.init(),
  ]);

  clientManager = await ClientManager.init();
  Diagnostics.setPostInit();

  shortcutsManager.init();
  NotificationManager.init();

  NeedsPostLoginInit.doPostLoginInit();
}

/// Initializes everything that is needed to run in GUI mode
Future<void> initGuiRequirements() async {
  isHeadless = false;

  MediaKit.ensureInitialized();

  var locale = PlatformDispatcher.instance.locale;

  await UnicodeEmojis.load();
  await initializeMessages(locale.languageCode);
  await initializeDateFormatting(locale.languageCode);

  Intl.defaultLocale = locale.languageCode;
}

/// Initializes gui requirements and launches the gui
Future<void> startGui() async {
  String? initialRoomId;
  String? initialClientId;

  initGuiRequirements();

  if (PlatformUtils.isAndroid) {
    enableEdgeToEdge();

    var initialIntent = await ReceiveIntent.getInitialIntent();
    ReceiveIntent.receivedIntentStream.listen((event) {
      Log.i("Received intent: ${initialIntent}");
      var uri = AndroidIntentHelper.getUriFromIntent(event);
      if (uri is OpenRoomURI) {
        EventBus.openRoom.add((uri.roomId, uri.clientId));
      }
    });

    Log.i("Initial intent: ${initialIntent}");

    var uri = AndroidIntentHelper.getUriFromIntent(initialIntent);

    if (uri is OpenRoomURI) {
      initialClientId = uri.clientId;
      initialRoomId = uri.roomId;
    }
  }

  double scale = preferences.appScale.value;

  ScaledWidgetsFlutterBinding.instance.scaleFactor = (deviceSize) {
    return scale;
  };

  var initialTheme = await preferences.resolveTheme();

  if (preferences.checkForUpdates.value == null &&
      UpdateChecker.shouldCheckForUpdates) {
    FirstTimeSetup.registerPostLoginSetup(UpdateCheckerSetup());
  }

  runApp(App(
    clientManager: clientManager!,
    initialTheme: initialTheme,
    initialClientId: initialClientId,
    initialRoom: initialRoomId,
  ));

  WindowManagement.init();
}

void enableEdgeToEdge() async {
  var theme = await preferences.resolveTheme();
  SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge); // Enable Edge-to-Edge on Android 10+
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor:
          Colors.transparent, // Setting a transparent navigation bar color
      systemNavigationBarContrastEnforced: true, // Default
      systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark));
}

class App extends StatefulWidget {
  const App(
      {super.key,
      required this.clientManager,
      this.initialTheme,
      this.initialRoom,
      this.initialClientId});
  final ThemeData? initialTheme;
  final ClientManager clientManager;

  final String? initialRoom;
  final String? initialClientId;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  // False whenever the app is not in the foreground (inactive, hidden, paused).
  // TickerMode propagates this down the tree, pausing all Ticker-driven
  // animations: shader backgrounds, ripple, shimmer, AnimationControllers.
  // Native media playback (VoIP, video/audio via media_kit) is unaffected
  // because it runs on its own threads outside the Flutter ticker system.
  // Animated GIFs/WebP are handled separately via PausableAnimatedImage.
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _active) setState(() => _active = active);
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _active,
      child: CustomSafeArea(
        child: FocusNodeMonitor(
          child: TextScaleChanger(
            child: ThemeChanger(
                shouldFollowSystemTheme: () =>
                    preferences.shouldFollowSystemTheme.value,
                getDarkTheme: () {
                  return preferences.resolveTheme(
                      overrideBrightness: Brightness.dark);
                },
                getLightTheme: () {
                  return preferences.resolveTheme(
                      overrideBrightness: Brightness.light);
                },
                initialTheme: widget.initialTheme ?? ThemeDark.theme,
                materialAppBuilder: (context, theme) {
                  return MaterialApp(
                    title: 'Tungstn',
                    theme: theme,
                    debugShowCheckedModeBanner: false,
                    navigatorKey: navigator,
                    builder: (context, child) => Provider<ClientManager>(
                      create: (context) => widget.clientManager,
                      child: child,
                    ),
                    home: AppView(
                      clientManager: widget.clientManager,
                      initialClientId: widget.initialClientId,
                      initialRoom: widget.initialRoom,
                    ),
                  );
                }),
          ),
        ),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView(
      {required this.clientManager,
      super.key,
      this.initialClientId,
      this.initialRoom});
  final ClientManager clientManager;
  final String? initialRoom;
  final String? initialClientId;

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  StreamSubscription? _onClientRemovedSubscription;
  StreamSubscription? _onClientAddedSubscription;

  @override
  void initState() {
    super.initState();
    _onClientRemovedSubscription =
        widget.clientManager.onClientRemoved.stream.listen((_) {
      if (!widget.clientManager.isLoggedIn()) {
        navigator.currentState?.popUntil((route) => route.isFirst);
        setState(() {});
      }
    });
    _onClientAddedSubscription =
        widget.clientManager.onClientAdded.stream.listen((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _onClientRemovedSubscription?.cancel();
    _onClientAddedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.clientManager.isLoggedIn()
        ? MainPage(
            widget.clientManager,
            initialClientId: widget.initialClientId,
            initialRoom: widget.initialRoom,
          )
        : LoginPage(onSuccess: (_) {
            setState(() {});
          });
  }
}

class AppStarter with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) return;
    if (loading != null) {
      await loading;
    }

    if (isHeadless) {
      startGui();
    }

    super.didChangeAppLifecycleState(state);
  }
}
