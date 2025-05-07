import 'dart:async';

import 'package:flutter/material.dart';
import 'package:macrodash_models/models.dart';

import 'api.dart';
import 'result.dart';

const Duration debounceDuration = Duration(milliseconds: 500);

class AsyncSearchAnchor extends StatefulWidget {
  const AsyncSearchAnchor({super.key, required this.controller});

  final SearchController controller;

  @override
  State<AsyncSearchAnchor> createState() => AsyncSearchAnchorState();
}

class AsyncSearchAnchorState extends State<AsyncSearchAnchor> {
  // The query currently being searched for. If null, there is no pending
  // request.
  String? _currentQuery;

  // The most recent suggestions received from the API.
  late Iterable<Widget> _lastOptions = <Widget>[];

  late final _Debounceable<List<TickerSearchEntry>?, String> _debouncedSearch;

  // Calls the "remote" API to search with the given query. Returns null when
  // the call has been made obsolete.
  Future<List<TickerSearchEntry>?> _search(String query) async {
    _currentQuery = query;

    // Call the search api.
    final api = ServerApi();
    final result = await api.searchTicker(_currentQuery!);
    switch (result) {
      case Ok():
        // If another search happened after this one, throw away these options.
        if (_currentQuery != query) {
          return null;
        }
        _currentQuery = null;

        return result.value.data;
      case Error():
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<List<TickerSearchEntry>?, String>(_search);
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: widget.controller,
      builder: (BuildContext context, SearchController controller) {
        return IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            controller.openView();
          },
        );
      },
      suggestionsBuilder: (
        BuildContext context,
        SearchController controller,
      ) async {
        final List<TickerSearchEntry>? options = (await _debouncedSearch(
          controller.text,
        ));
        if (options == null) {
          return _lastOptions;
        }
        _lastOptions = List<ListTile>.generate(options.length, (int index) {
          final item = options[index];
          return ListTile(
            title: Text(item.name),
            subtitle: Text(item.ticker),
            onTap: () {
              debugPrint('You just selected $item');
              controller.closeView(item.ticker);
            },
          );
        });

        return _lastOptions;
      },
    );
  }
}

typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
///
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer();
    try {
      await debounceTimer!.future;
    } on _CancelException {
      return null;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer() {
    _timer = Timer(debounceDuration, _onComplete);
  }

  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError(const _CancelException());
  }
}

// An exception indicating that the timer was canceled.
class _CancelException implements Exception {
  const _CancelException();
}
