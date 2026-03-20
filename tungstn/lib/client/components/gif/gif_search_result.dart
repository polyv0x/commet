class GifSearchResult {
  final Uri previewUrl;
  final Uri fullResUrl;
  final double x;
  final double y;
  final String mimeType;

  GifSearchResult(
      this.previewUrl, this.fullResUrl, this.x, this.y, this.mimeType);
}

class GifSearchResponse {
  final List<GifSearchResult> results;

  /// Opaque cursor to pass as `pos` in the next request.
  /// Null or empty means no more results.
  final String? next;

  GifSearchResponse(this.results, this.next);
}
