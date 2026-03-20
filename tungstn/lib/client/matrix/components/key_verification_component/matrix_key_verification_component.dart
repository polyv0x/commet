import 'package:tungstn/client/components/component.dart';
import 'package:tungstn/client/matrix/matrix_client.dart';
import 'package:tungstn/debug/log.dart';
import 'package:tungstn/main.dart';
import 'package:tungstn/ui/navigation/adaptive_dialog.dart';
import 'package:tungstn/ui/pages/matrix/authentication/matrix_uia_request.dart';
import 'package:tungstn/ui/pages/matrix/verification/matrix_verification_page.dart';

import 'package:matrix/matrix.dart' as matrix;

class MatrixKeyVerificationComponent
    implements Component<MatrixClient>, NeedsPostLoginInit {
  @override
  MatrixClient client;

  MatrixKeyVerificationComponent(this.client);

  @override
  void postLoginInit() {
    Log.i("Registering key verification listeners");
    client.matrixClient.onKeyVerificationRequest.stream.listen((event) {
      AdaptiveDialog.show(
        navigator.currentContext!,
        builder: (_) => MatrixVerificationPage(request: event),
        title: "Verification Request",
      );
    });

    client.matrixClient.onUiaRequest.stream.listen((event) {
      if (event.state == matrix.UiaRequestState.waitForUser) {
        AdaptiveDialog.show(
          navigator.currentContext!,
          builder: (_) => MatrixUIARequest(event, client),
          title: "Authentication Request",
        );
      }
    });
  }
}
