import 'package:tungstn/client/client.dart';
import 'package:tungstn/client/components/space_component.dart';
import 'package:flutter/material.dart';

abstract class SpaceColorSchemeComponent<R extends Client, T extends Space>
    implements SpaceComponent<R, T> {
  ColorScheme get scheme;
}
