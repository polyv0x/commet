import 'dart:ui';

import 'package:commet/config/build_config.dart';
import 'package:commet/main.dart' show preferences;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:tiamat/tiamat.dart' as tiamat;
import '../../utils/debounce.dart';
import '../../client/components/gif/gif_search_result.dart';
import '../atoms/shimmer_loading.dart';

class GifPicker extends StatefulWidget {
  const GifPicker(
      {super.key,
      this.gifPicked,
      this.search,
      this.focus,
      this.placeholderText = "Search Gif"});
  final Future<void> Function(GifSearchResult gif)? gifPicked;
  final Future<GifSearchResponse> Function(String query, {String? pos})? search;
  final FocusNode? focus;
  final String placeholderText;

  @override
  State<GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<GifPicker> {
  List<GifSearchResult>? searchResult;
  bool searching = false;
  bool sending = false;
  bool loadingMore = false;
  bool hasMore = false;
  String? nextCursor;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Debouncer debouce = Debouncer(delay: const Duration(milliseconds: 500));

  @override
  void initState() {
    _textController.addListener(onTextChanged);
    _scrollController.addListener(_onScroll);
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    final count = searchResult?.length ?? 0;
    searchResult?.forEach(
        (r) => NetworkImage(r.fullResUrl.toString()).evict());
    if (preferences.developerMode.value) {
      debugPrint('[GifPicker] disposed — evicted $count GIFs from image cache');
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 1500) {
      loadMore();
    }
  }

  String prevText = "";
  void onTextChanged() {
    if (_textController.text == prevText) return;
    prevText = _textController.text;

    if (_textController.text.isNotEmpty) {
      setState(() {
        searching = true;
        searchResult = null;
        nextCursor = null;
        hasMore = false;
      });
      debouce.run(() => doSearch(_textController.text));
    } else {
      debouce.cancel();
      setState(() {
        searching = false;
      });
    }
  }

  void doSearch(String query) {
    setState(() {
      searching = true;
    });

    widget.search?.call(query).then((response) {
      if (!mounted) return;
      setState(() {
        searchResult = response.results;
        nextCursor = response.next;
        hasMore = response.next != null && response.next!.isNotEmpty;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        searchResult = [];
        hasMore = false;
      });
    });
  }

  void loadMore() {
    if (loadingMore || !hasMore) return;
    final query = _textController.text;
    if (query.isEmpty) return;

    setState(() {
      loadingMore = true;
    });

    widget.search?.call(query, pos: nextCursor).then((response) {
      if (!mounted) return;
      setState(() {
        searchResult = [...searchResult!, ...response.results];
        nextCursor = response.next;
        hasMore = response.next != null && response.next!.isNotEmpty;
        loadingMore = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        loadingMore = false;
      });
    });
  }

  void removeResult(GifSearchResult result) {
    if (!mounted) return;
    setState(() {
      searchResult?.remove(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      buildContent(context),
      if (sending)
        BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 2, sigmaY: 2, tileMode: TileMode.repeated),
          child: Container(
            color: Colors.black.withAlpha(100),
            child: const Center(
                child: SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(),
            )),
          ),
        ),
    ]);
  }

  Widget buildContent(BuildContext context) {
    if (BuildConfig.MOBILE) {
      return Column(children: [buildSearchBar(), buildSearch(context)]);
    } else {
      return Column(children: [buildSearch(context), buildSearchBar()]);
    }
  }

  Widget buildSearchBar() {
    return tiamat.Tile.low(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
            height: BuildConfig.DESKTOP ? 30 : null,
            child: TextField(
              controller: _textController,
              focusNode: widget.focus,
              decoration: InputDecoration(
                  icon: const Icon(Icons.search),
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.placeholderText),
            )),
      ),
    );
  }

  Widget buildSearch(BuildContext context) {
    if (!searching) {
      return const Expanded(child: SizedBox());
    }

    if (searchResult == null) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: MasonryGridView.extent(
                controller: _scrollController,
                maxCrossAxisExtent: 300,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: searchResult!.length,
                itemBuilder: (context, index) {
                  final result = searchResult![index];
                  return _GifGridItem(
                    key: ValueKey(result.fullResUrl),
                    result: result,
                    onTap: () => sendGif(result),
                    onError: () => removeResult(result),
                  );
                },
              ),
            ),
          ),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  void sendGif(GifSearchResult gif) {
    setState(() {
      sending = true;
    });

    widget.gifPicked?.call(gif).then((_) => setState(() {
          sending = false;
        }));
  }
}

class _GifGridItem extends StatefulWidget {
  const _GifGridItem({
    required this.result,
    required this.onTap,
    required this.onError,
    super.key,
  });

  final GifSearchResult result;
  final VoidCallback onTap;
  final VoidCallback onError;

  @override
  State<_GifGridItem> createState() => _GifGridItemState();
}

class _GifGridItemState extends State<_GifGridItem> {
  bool isLoading = true;
  Widget? _frozenFrame;

  @override
  void dispose() {
    if (preferences.developerMode.value) {
      debugPrint('[GifPicker] grid item evicted: ${widget.result.fullResUrl}');
    }
    NetworkImage(widget.result.fullResUrl.toString()).evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: widget.result.x / widget.result.y,
            child: Shimmer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ShimmerLoading(
                    isLoading: isLoading,
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                    ),
                  ),
                  Image(
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    image: NetworkImage(widget.result.fullResUrl.toString()),
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (frame != null) {
                        if (isLoading) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => isLoading = false);
                          });
                        }
                        if (TickerMode.of(context)) {
                          _frozenFrame = child;
                        }
                        return _frozenFrame ?? child;
                      }
                      return const SizedBox.shrink();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => widget.onError());
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
