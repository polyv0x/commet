import 'dart:async';

import 'package:commet/client/call_manager.dart';
import 'package:commet/client/components/voip/voip_session.dart';
import 'package:commet/config/preferences.dart';
import 'package:commet/main.dart';
import 'package:commet/ui/organisms/call_view/call_view.dart';
import 'package:flutter/material.dart';
import 'package:tiamat/tiamat.dart' as tiamat;

class VoiceStatusPanel extends StatefulWidget {
  const VoiceStatusPanel(this.callManager, {super.key});
  final CallManager callManager;

  @override
  State<VoiceStatusPanel> createState() => _VoiceStatusPanelState();
}

class _VoiceStatusPanelState extends State<VoiceStatusPanel>
    with TickerProviderStateMixin {
  late List<StreamSubscription> _subs;
  bool _showStreamSettings = false;
  AnimationController? _audioLevel;
  StreamSubscription? _sessionSub;
  StreamSubscription? _audioSub;

  VoipSession? get _session =>
      widget.callManager.currentSessions.firstOrNull;

  @override
  void initState() {
    super.initState();
    _subs = [
      widget.callManager.currentSessions.onListUpdated.listen((_) {
        _rebindSession();
        setState(() {});
      }),
    ];
    _rebindSession();
  }

  void _rebindSession() {
    _sessionSub?.cancel();
    _audioSub?.cancel();
    _audioLevel?.dispose();
    _audioLevel = null;

    final session = _session;
    if (session == null) return;

    _audioLevel = AnimationController(
        vsync: this, duration: CallView.volumeAnimationDuration);

    _sessionSub = session.onStateChanged.listen((_) => setState(() {}));
    _audioSub = session.onUpdateVolumeVisualizers.listen((_) async {
      await session.updateStats();
      if (mounted) setState(() {});
      _audioLevel?.animateTo(session.generalAudioLevel);
    });
  }

  @override
  void dispose() {
    for (var sub in _subs) {
      sub.cancel();
    }
    _sessionSub?.cancel();
    _audioSub?.cancel();
    _audioLevel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    if (session.state == VoipState.ended) return const SizedBox.shrink();

    final room = session.client.getRoom(session.roomId);
    final spaceName = clientManager?.spaces
        .where((s) => s.containsRoom(session.roomId))
        .firstOrNull
        ?.displayName;

    final roomLabel = spaceName != null
        ? '${room?.displayName ?? session.roomName} / $spaceName'
        : (room?.displayName ?? session.roomName);

    final connected = session.state == VoipState.connected;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const tiamat.Seperator(),
          _statusHeader(context, session, roomLabel, connected),
          if (connected) _actionButtons(context, session),
          if (_showStreamSettings &&
              connected &&
              (session.isSharingScreen || session.isCameraEnabled))
            _streamSettingsPanel(context),
          const tiamat.Seperator(),
        ],
      ),
    );
  }

  Widget _statusHeader(BuildContext context, VoipSession session,
      String roomLabel, bool connected) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = connected ? Colors.lightGreen : scheme.primary;
    final statusText = switch (session.state) {
      VoipState.connected => 'Voice Connected',
      VoipState.connecting => 'Connecting...',
      VoipState.outgoing => 'Calling...',
      _ => session.state.name,
    };

    final latency = session.latencyMs;
    final latencyLabel =
        latency != null ? '${latency.round()} ms' : 'Unknown';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Network icon spanning both rows
            Tooltip(
              message: latencyLabel,
              preferBelow: false,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.outlineVariant, width: 1),
              ),
              textStyle: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurface),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 6, 0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(5),
                      border:
                          Border.all(color: statusColor.withAlpha(80), width: 1),
                    ),
                    child: Icon(Icons.wifi, color: statusColor, size: 14),
                  ),
                ),
              ),
            ),
            // Middle: two lines of text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        statusText,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: statusColor),
                      ),
                      if (connected && _audioLevel != null) ...[
                        const SizedBox(width: 6),
                        AnimatedBuilder(
                          animation: _audioLevel!,
                          builder: (context, _) =>
                              _audioLevelBars(_audioLevel!.value, statusColor),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roomLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withAlpha(180)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Disconnect button spanning both rows
            SizedBox(
              width: 36,
              child: tiamat.IconButton(
                icon: Icons.call_end,
                iconColor: scheme.error,
                size: 16,
                onPressed: () => session.hangUpCall(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioLevelBars(double level, Color color) {
    const barCount = 3;
    const barWidth = 3.0;
    const maxHeight = 10.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 2,
      children: List.generate(barCount, (i) {
        final threshold = (i + 1) / barCount;
        final active = level >= threshold;
        return Container(
          width: barWidth,
          height: maxHeight * ((i + 1) / barCount),
          decoration: BoxDecoration(
            color: active ? color : color.withAlpha(60),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _actionButtons(BuildContext context, VoipSession session) {
    const radius = 16.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        spacing: 4,
        children: [
          if (session.supportsScreenshare) ...[
            if (!session.isSharingScreen)
              tiamat.CircleButton(
                radius: radius,
                icon: Icons.screen_share_outlined,
                onPressed: () async {
                  final source = await session.pickScreenCapture(context);
                  if (source != null) await session.setScreenShare(source);
                },
              ),
            if (session.isSharingScreen)
              tiamat.CircleButton(
                radius: radius,
                icon: Icons.stop_screen_share,
                onPressed: () => session.stopScreenshare(),
              ),
          ],
          if (session.isCameraEnabled)
            tiamat.CircleButton(
              radius: radius,
              icon: Icons.no_photography,
              onPressed: () => session.stopCamera(),
            )
          else
            tiamat.CircleButton(
              radius: radius,
              icon: Icons.camera_alt_outlined,
              onPressed: () => session.setCamera(null),
            ),
          if (session.isSharingScreen || session.isCameraEnabled)
            tiamat.CircleButton(
              radius: radius,
              icon: _showStreamSettings
                  ? Icons.settings
                  : Icons.settings_outlined,
              onPressed: () =>
                  setState(() => _showStreamSettings = !_showStreamSettings),
            ),
        ],
      ),
    );
  }

  Widget _streamSettingsPanel(BuildContext context) {
    final resOptions = Preferences.streamResolutionOptions;
    final fpsOptions = Preferences.streamFramerateOptions;
    final resIdx = resOptions
        .indexOf(preferences.streamResolution.value)
        .clamp(0, resOptions.length - 1)
        .toDouble();
    final fpsIdx = fpsOptions
        .indexOf(preferences.streamFramerate.value)
        .clamp(0, fpsOptions.length - 1)
        .toDouble();
    final bitrate = preferences.streamBitrate.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sliderRow(
            context,
            label: 'Res',
            valueLabel: resOptions[resIdx.round()],
            value: resIdx,
            min: 0,
            max: (resOptions.length - 1).toDouble(),
            divisions: resOptions.length - 1,
            onChanged: (v) {
              preferences.streamResolution.set(resOptions[v.round()]);
              setState(() {});
            },
          ),
          _sliderRow(
            context,
            label: 'FPS',
            valueLabel: fpsOptions[fpsIdx.round()],
            value: fpsIdx,
            min: 0,
            max: (fpsOptions.length - 1).toDouble(),
            divisions: fpsOptions.length - 1,
            onChanged: (v) {
              preferences.streamFramerate.set(fpsOptions[v.round()]);
              setState(() {});
            },
          ),
          _sliderRow(
            context,
            label: 'Mbps',
            valueLabel:
                bitrate == 0 ? 'Auto' : bitrate.toStringAsFixed(0),
            value: bitrate,
            min: Preferences.streamBitrateMin,
            max: Preferences.streamBitrateMax,
            divisions: Preferences.streamBitrateMax.toInt(),
            onChanged: (v) {
              preferences.streamBitrate.set(v.roundToDouble());
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context, {
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: tiamat.Text.labelLow(label),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
