import 'dart:async';

import 'package:commet/client/components/voip/voip_session.dart';
import 'package:commet/client/components/voip_room/voip_room_component.dart';
import 'package:commet/client/matrix/components/matrix_sync_listener.dart';
import 'package:commet/client/matrix/components/voip_room/matrix_livekit_backend.dart';
import 'package:commet/client/matrix/matrix_client.dart';
import 'package:commet/client/matrix/matrix_room.dart';
import 'package:matrix/matrix.dart';

class MatrixVoipRoomComponent
    implements
        VoipRoomComponent<MatrixClient, MatrixRoom>,
        MatrixRoomSyncListener {
  static const callMemberStateEvent = "org.matrix.msc3401.call.member";

  @override
  MatrixClient client;

  @override
  MatrixRoom room;

  late MatrixLivekitBackend backend;

  VoipSession? currentSession;

  MatrixVoipRoomComponent(this.client, this.room) {
    backend = MatrixLivekitBackend(room);
    _scheduleExpiryRefresh();
  }

  static bool isVoipRoom(MatrixRoom room) {
    return room.matrixRoom.getState(EventTypes.RoomCreate)?.content['type'] ==
        "org.matrix.msc3417.call";
  }

  StreamController _onParticipantsChanged = StreamController.broadcast();
  Timer? _expiryTimer;
  StreamSubscription? _sessionParticipantsSub;

  @override
  onSync(JoinedRoomUpdate update) {
    final hasCallMemberEvent =
        update.timeline?.events?.any((e) => e.type == callMemberStateEvent) ==
                true ||
            update.state?.any((e) => e.type == callMemberStateEvent) ==
                true;

    if (hasCallMemberEvent) {
      _scheduleExpiryRefresh();
      _onParticipantsChanged.add(());
    }
  }

  // Cap effective expiry at 2 minutes — any actively connected client will
  // refresh via heartbeat well within this window. Prevents ghost users from
  // other clients that set very long expires values (e.g. 4 hours).
  static const _maxExpiryMs = 120000;

  /// Returns the expiry time for a call membership state event, or null if
  /// it cannot be determined (missing `expires` field and no timestamp source).
  DateTime? _getMembershipExpiry(StrippedStateEvent stateEvent) {
    var expiresMs = stateEvent.content.tryGet<num>('expires');
    if (expiresMs == null) return null;

    // Clamp to our maximum so foreign 4-hour values don't create long ghosts.
    if (expiresMs.toInt() > _maxExpiryMs) {
      expiresMs = _maxExpiryMs;
    }

    // Prefer created_ts from content (works regardless of StrippedStateEvent
    // vs Event), fall back to originServerTs on full Event instances.
    final createdTs = stateEvent.content.tryGet<num>('created_ts');
    if (createdTs != null) {
      return DateTime.fromMillisecondsSinceEpoch(createdTs.toInt(), isUtc: true)
          .add(Duration(milliseconds: expiresMs.toInt()));
    }

    if (stateEvent is Event) {
      return stateEvent.originServerTs
          .add(Duration(milliseconds: expiresMs.toInt()));
    }

    return null;
  }

  /// Returns true if the call membership event has expired based on its
  /// `expires` field relative to `created_ts` (or `originServerTs`).
  /// If the event has an `expires` field but no timestamp source to check
  /// against, it is treated as expired (fail-closed) to avoid ghost users.
  bool _isMembershipExpired(StrippedStateEvent stateEvent) {
    final hasExpires = stateEvent.content.tryGet<num>('expires') != null;
    final expiry = _getMembershipExpiry(stateEvent);

    // Has an expires field but no way to determine when it was created —
    // treat as expired rather than showing a potentially stale user.
    if (hasExpires && expiry == null) return true;

    if (expiry == null) return false;
    return DateTime.now().toUtc().isAfter(expiry);
  }

  /// Schedules a timer to fire [onParticipantsChanged] when the next
  /// membership is due to expire, so the UI removes stale participants
  /// automatically.
  void _scheduleExpiryRefresh() {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    final state = room.matrixRoom.states[callMemberStateEvent];
    if (state == null) return;

    final now = DateTime.now().toUtc();
    Duration? shortest;

    for (var pair in state.entries) {
      if (pair.value.content.isEmpty) continue;

      final expiry = _getMembershipExpiry(pair.value);
      if (expiry == null) continue;

      if (expiry.isAfter(now)) {
        final remaining = expiry.difference(now);
        if (shortest == null || remaining < shortest) {
          shortest = remaining;
        }
      }
    }

    if (shortest != null) {
      _expiryTimer = Timer(shortest, () {
        _scheduleExpiryRefresh();
        _onParticipantsChanged.add(());
      });
    }
  }

  @override
  List<String> getCurrentParticipants() {
    // When we have an active session, use the LiveKit room's actual participant
    // list — this is the ground truth for who is really connected.
    if (currentSession != null) {
      return currentSession!.connectedParticipants;
    }

    // When not connected, fall back to Matrix state events (with expiry
    // filtering) so we can still show who's in the call before joining.
    final state = room.matrixRoom.states[callMemberStateEvent];
    if (state == null) {
      return [];
    }

    final localUserId = client.matrixClient.userID;

    List<String> participants = List.empty(growable: true);

    for (var pair in state.entries) {
      if (pair.value.content.isEmpty) {
        continue;
      }

      // Skip memberships that have expired based on created_ts + expires.
      if (_isMembershipExpired(pair.value)) {
        continue;
      }

      final sender = pair.value.senderId;

      // Optimistically exclude ourselves if we've left the call, before the
      // server sync comes back with our cleared state.
      if (sender == localUserId) {
        continue;
      }

      if (participants.contains(sender)) {
        continue;
      }

      participants.add(sender);
    }

    return participants;
  }

  @override
  Stream<void> get onParticipantsChanged => _onParticipantsChanged.stream;

  @override
  Future<VoipSession?> joinCall() async {
    currentSession = await backend.join();
    currentSession?.onStateChanged.listen(onStateChanged);
    _sessionParticipantsSub = currentSession?.onParticipantsChanged.listen((_) {
      _onParticipantsChanged.add(());
    });
    _scheduleExpiryRefresh();
    _onParticipantsChanged.add(());
    return currentSession;
  }

  @override
  Future<String?> getCallServerUrl() async {
    final url = await backend.getFociUrl();
    return url.firstOrNull?.authority.toString();
  }

  void onStateChanged(void event) {
    final state = currentSession?.state;
    print("Got call state: ${state}");

    if (state == VoipState.ended) {
      _sessionParticipantsSub?.cancel();
      _sessionParticipantsSub = null;
      currentSession = null;
      _onParticipantsChanged.add(());
    }
  }

  @override
  bool get canJoinCall => room.matrixRoom.canChangeStateEvent(
        MatrixVoipRoomComponent.callMemberStateEvent,
      );

  @override
  Future<void> clearAllCallMembershipStatus() async {
    final state = room.matrixRoom.states[callMemberStateEvent];
    if (state == null) {
      return;
    }

    var futures = [
      for (var entry in state.entries)
        if (entry.value.senderId == client.matrixClient.userID)
          client.matrixClient.setRoomStateWithKey(
            room.identifier,
            MatrixVoipRoomComponent.callMemberStateEvent,
            entry.key,
            {},
          ),
    ];

    await Future.wait(futures);
  }
}
