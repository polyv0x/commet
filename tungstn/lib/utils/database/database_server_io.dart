import 'package:tungstn/utils/database/multiple_database_server.dart';

Future<void>? initDatabaseServerImpl() async {
  await DatabaseIsolate.start();
}
