import 'dart:io';
import 'dart:typed_data';

class DownloadProgress {
  int downloaded;
  int total;

  DownloadProgress(this.downloaded, this.total);
}

abstract class FileProvider {
  Future<Uri?> resolve();

  Future<void> save(String filepath);

  Stream<DownloadProgress>? get onProgressChanged;

  Future<Uint8List?> getFileData();

  String get fileIdentifier;
}

class UrlFileProvider implements FileProvider {
  final Uri url;

  UrlFileProvider(this.url);

  @override
  String get fileIdentifier => url.toString();

  @override
  Future<Uri?> resolve() async => url;

  @override
  Stream<DownloadProgress>? get onProgressChanged => null;

  @override
  Future<Uint8List?> getFileData() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> save(String filepath) async {
    final data = await getFileData();
    if (data != null) await File(filepath).writeAsBytes(data);
  }
}

class SystemFileProvider implements FileProvider {
  File file;

  @override
  String get fileIdentifier => file.path;

  @override
  Future<Uri?> resolve() async {
    return file.uri;
  }

  @override
  Future<void> save(String filepath) {
    throw UnimplementedError();
  }

  SystemFileProvider(this.file);

  @override
  Stream<DownloadProgress>? get onProgressChanged => null;

  @override
  Future<Uint8List?> getFileData() {
    return file.readAsBytes();
  }
}
