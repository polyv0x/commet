import 'dart:async';

import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/voip/voip_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum VoipState {
  incoming,
  connecting,
  connected,
  unknown,
  outgoing,
  ended,
}

abstract class ScreenCaptureSource {}

abstract class VoipSession {
  Client get client;

  String get sessionId;

  String get roomId;

  String? get remoteUserId;

  String? get remoteUserName;

  String get roomName;

  VoipState get state;

  bool get isMicrophoneMuted;

  bool get isDeafened;

  bool get supportsScreenshare;

  bool get isSharingScreen;

  bool get isCameraEnabled;

  double get generalAudioLevel;

  /// Round-trip time in milliseconds, or null if unavailable.
  double? get latencyMs;

  /// Fraction of packets lost [0.0–1.0], or null if unavailable.
  double? get packetLossRate;

  VoipStream? get remoteUserMediaStream;

  List<VoipStream> get streams;

  Future<void> acceptCall(
      {bool withMicrophone = false, bool withCamera = false});

  Future<void> declineCall();

  Future<void> hangUpCall();

  Stream<VoipState> get onConnectionStateChanged;

  Stream<void> get onStateChanged;

  Stream<void> get onUpdateVolumeVisualizers;

  Future<void> setMicrophoneMute(bool state);

  Future<void> setDeafened(bool state);

  Future<void> updateStats();

  Future<ScreenCaptureSource?> pickScreenCapture(BuildContext context);

  Future<void> setScreenShare(ScreenCaptureSource source);

  Future<void> stopScreenshare();

  /// User IDs of participants actually connected to the call.
  List<String> get connectedParticipants;

  /// Fires when participants connect or disconnect from the call.
  Stream<void> get onParticipantsChanged;

  Future<void> setCamera(MediaDeviceInfo? device);

  Future<void> stopCamera();
}
