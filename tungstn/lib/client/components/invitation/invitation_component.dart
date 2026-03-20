import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/component.dart';
import 'package:tungstn/client/components/invitation/invitation.dart';
import 'package:tungstn/client/components/profile/profile_component.dart';
import 'package:tungstn/utils/notifying_list.dart';

abstract class InvitationComponent<T extends Client> implements Component<T> {
  NotifyingList<Invitation> get invitations;

  Future<void> acceptInvitation(Invitation invitation);

  Future<void> rejectInvitation(Invitation invitation);

  Future<void> inviteUserToRoom(
      {required String userId, required String roomId});

  Future<List<Profile>> searchUsers(String term);
}
