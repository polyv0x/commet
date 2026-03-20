import 'dart:convert';

import 'package:http/http.dart' as http;

class OEmbedResult {
  final String? title;
  final String? authorName;
  final String? thumbnailUrl;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final String? providerName;
  final String? type;

  OEmbedResult({
    this.title,
    this.authorName,
    this.thumbnailUrl,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.providerName,
    this.type,
  });

  factory OEmbedResult.fromJson(Map<String, dynamic> json) {
    return OEmbedResult(
      title: json['title'] as String?,
      authorName: json['author_name'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      thumbnailWidth: (json['thumbnail_width'] as num?)?.toDouble(),
      thumbnailHeight: (json['thumbnail_height'] as num?)?.toDouble(),
      providerName: json['provider_name'] as String?,
      type: json['type'] as String?,
    );
  }
}

class _OEmbedProvider {
  final List<RegExp> patterns;
  final String Function(String url) endpointBuilder;

  const _OEmbedProvider(this.patterns, this.endpointBuilder);

  bool matches(Uri uri) {
    final urlStr = uri.toString();
    return patterns.any((p) => p.hasMatch(urlStr));
  }
}

class OEmbedService {
  static final _providers = [
    _OEmbedProvider(
      [
        RegExp(r'youtube\.com/watch'),
        RegExp(r'youtu\.be/'),
        RegExp(r'youtube\.com/shorts/'),
      ],
      (url) =>
          'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json',
    ),
    _OEmbedProvider(
      [RegExp(r'vimeo\.com/\d')],
      (url) =>
          'https://vimeo.com/api/oembed.json?url=${Uri.encodeComponent(url)}',
    ),
    _OEmbedProvider(
      [RegExp(r'soundcloud\.com/')],
      (url) =>
          'https://soundcloud.com/oembed?url=${Uri.encodeComponent(url)}&format=json',
    ),
  ];

  static _OEmbedProvider? _findProvider(Uri uri) {
    for (final provider in _providers) {
      if (provider.matches(uri)) return provider;
    }
    return null;
  }

  static bool hasProvider(Uri uri) => _findProvider(uri) != null;

  static Future<OEmbedResult?> fetch(Uri uri) async {
    final provider = _findProvider(uri);
    if (provider == null) return null;

    try {
      final endpointUrl = provider.endpointBuilder(uri.toString());
      final response = await http
          .get(Uri.parse(endpointUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return OEmbedResult.fromJson(data);
      }
    } catch (_) {}

    return null;
  }
}
