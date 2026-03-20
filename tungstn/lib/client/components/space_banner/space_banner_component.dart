import 'dart:typed_data';

import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/space_component.dart';
import 'package:flutter/widgets.dart';

abstract class SpaceBannerComponent<R extends Client, T extends Space>
    implements SpaceComponent<R, T> {
  ImageProvider? get banner;

  bool get canEditBanner;

  Future<void> setBanner(Uint8List data, {String? mimeType});
}
