import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import 'package:macrodash_models/models.dart';

import 'api.dart';
import 'option_buttons.dart';
import 'vis.dart';
import 'vis2.dart';
import 'settings.dart';
import 'result.dart';

final Logger log = Logger('amount_series_page');

class AmountSeriesPage<T extends Enum, C extends Enum> extends StatefulWidget {
  const AmountSeriesPage({
    super.key,
    required this.title,
    required this.chartLibrary,
    required this.region,
    required this.regions,
    required this.regionLabels,
    this.category,
    this.categories = const [],
    this.categoryLabels = const [],
    this.categoryTitles = const [],
    this.zoom,
  });

  final String title;
  final ChartLibrary chartLibrary;
  final String? region;
  final List<T> regions;
  final Map<T, String> regionLabels;
  final String? category;
  final List<List<C>> categories;
  final List<Map<C, String>> categoryLabels;
  final List<String> categoryTitles;
  final String? zoom;

  @override
  State<AmountSeriesPage<T, C>> createState() => _AmountSeriesPageState<T, C>();
}

class _AmountSeriesPageState<T extends Enum, C extends Enum>
    extends State<AmountSeriesPage<T, C>> {
  final ServerApi _api = ServerApi();
  AmountSeries? _amountSeries;
  List<AmountEntry> _filteredData = [];
  bool _isLoading = true;
  late T _selectedRegion;
  C? _selectedCategory;
  DataRange _selectedZoom = DataRange.max; // Default to 'Max'

  @override
  void initState() {
    super.initState();
    // Initialize with the default region
    _selectedRegion =
        widget.region != null
            ? widget.regions.firstWhere(
              (region) => region.name == widget.region,
            )
            : widget.regions.first;
    // Initialize with the default category
    if (widget.categories.isNotEmpty) {
      _selectedCategory =
          widget.category != null
              ? widget.categories[_getCategoryIndexFromRegion()].firstWhere(
                (category) => category.name == widget.category,
              )
              : widget.categories[_getCategoryIndexFromRegion()].first;
    }
    // Initialize with the default zoom level
    if (widget.zoom != null) {
      _selectedZoom = DataRange.values.firstWhere(
        (zoom) => zoom.name == widget.zoom,
      );
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    final result = await _api.fetchAmountSeries(
      _selectedRegion,
      _selectedCategory,
      _selectedZoom,
    );
    switch (result) {
      case Ok():
        _amountSeries = result.value;
      case Error():
        // show snackbar
        if (mounted) {
          var snackBar = SnackBar(
            content: Text('Unable to get data! - ${result.error}'),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
    }

    setState(() {
      _isLoading = false;
      _amountSeries = _amountSeries;
      if (_amountSeries == null) {
        return;
      }
      _applyFilter(_selectedZoom);
    });
  }

  void _regionSelect(T region) {
    Settings.saveChartSetting(widget.title, 'region', region.name);
    setState(() {
      _selectedRegion = region;
      if (widget.categories.isNotEmpty) {
        _selectedCategory =
            widget.categories[_getCategoryIndexFromRegion()].first;
      }
      _fetchData();
    });
  }

  void _categorySelect(C category) {
    Settings.saveChartSetting(widget.title, 'category', category.name);
    setState(() {
      _selectedCategory = category;
      _fetchData();
    });
  }

  void _filterData(DataRange zoomLevel) {
    Settings.saveChartSetting(widget.title, 'zoom', zoomLevel.name);
    setState(() {
      _selectedZoom = zoomLevel;
      _fetchData().then((_) {
        _applyFilter(zoomLevel);
      });
    });
  }

  void _applyFilter(DataRange zoomLevel) {
    setState(() {
      if (_amountSeries == null) {
        log.severe('No series data available to filter.');
        return;
      }

      if (zoomLevel == DataRange.max) {
        // Show all data (Max)
        _filteredData = _amountSeries!.data;
      } else {
        final years = switch (zoomLevel) {
          DataRange.oneDay => 1 / 365,
          DataRange.fiveDays => 5 / 365,
          DataRange.oneMonth => 1 / 12,
          DataRange.threeMonths => 3 / 12,
          DataRange.sixMonths => 6 / 12,
          DataRange.oneYear => 1,
          DataRange.twoYears => 2,
          DataRange.fiveYears => 5,
          DataRange.tenYears => 10,
          DataRange.max => throw Exception('Invalid zoom level'),
        };
        // Calculate the cutoff date based on the selected zoom level
        // and filter the data accordingly
        final cutoffDate = DateTime.now().subtract(
          Duration(days: (years * 365).toInt()),
        );
        _filteredData =
            _amountSeries!.data
                .where((entry) => entry.date.isAfter(cutoffDate))
                .toList();
      }
    });
  }

  int _getCategoryIndexFromRegion() {
    // if only one category list use it for all regions
    if (widget.categories.length == 1) {
      return 0;
    }
    // return the category list that matches the region
    // (region list and category list should be the same size)
    for (int i = 0; i < widget.regions.length; i++) {
      if (widget.regions[i] == _selectedRegion) {
        return i;
      }
    }
    throw Exception('Region not found in the list');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final smallWidth = size.width < 600;
    final smallHeight = size.height < 400;
    final hPadding = smallWidth ? 2.0 : 16.0;
    final vPadding = smallHeight ? 2.0 : 16.0;
    final popouts = smallWidth || smallHeight;
    final optionsSide = smallHeight;
    final fullscreenButton = FullscreenButton();
    final shareButton = ShareButton(
      uri: GoRouterState.of(context).uri,
      queryParams: {
        'region': _selectedRegion.name,
        'category': _selectedCategory?.name ?? '',
        'zoom': _selectedZoom.name,
      },
    );
    final regionButtons = OptionButtons<T>(
      popoutTitle: 'Region',
      selectedOption: _selectedRegion,
      values: widget.regions,
      onOptionSelected: _regionSelect,
      labels: widget.regionLabels,
      popout: popouts,
    );
    final categoryButtons =
        (widget.categories.isNotEmpty)
            ? OptionButtons<C>(
              popoutTitle: widget.categoryTitles[_getCategoryIndexFromRegion()],
              selectedOption: _selectedCategory!,
              values: widget.categories[_getCategoryIndexFromRegion()],
              onOptionSelected: _categorySelect,
              labels: widget.categoryLabels[_getCategoryIndexFromRegion()],
              popout: popouts,
            )
            : const SizedBox();
    final zoomButtons = ZoomButtons(
      selectedZoom: _selectedZoom,
      onZoomSelected: (zoomLevel) => _filterData(zoomLevel),
      popout: popouts,
    );
    final Widget options = switch (optionsSide) {
      true => Padding(
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: vPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [regionButtons, categoryButtons, zoomButtons],
        ),
      ),
      false => Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [regionButtons, categoryButtons, zoomButtons],
        ),
      ),
    };
    final chart =
        _isLoading
            ? Expanded(child: const Center(child: CircularProgressIndicator()))
            : _amountSeries == null
            ? Expanded(child: const Center(child: Text('No data available.')))
            :
            // Line Chart
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hPadding,
                  vertical: vPadding,
                ),
                child: switch (widget.chartLibrary) {
                  ChartLibrary.flChart => Vis(
                    filteredData: _filteredData,
                    dataSeries: _amountSeries,
                    selectedZoom: _selectedZoom,
                  ),
                  ChartLibrary.financialChart => VisFinancialChart(
                    filteredData: _filteredData,
                    dataSeries: _amountSeries,
                    selectedZoom: _selectedZoom,
                  ),
                },
              ),
            );
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} Data Visualization'),
        actions: [if (kIsWeb) fullscreenButton, shareButton],
      ),
      body:
          optionsSide
              ? Row(children: [options, chart])
              : Column(children: [options, chart]),
    );
  }
}
