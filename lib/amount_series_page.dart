import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:macrodash_models/models.dart';

import 'api.dart';
import 'option_buttons.dart';
import 'vis.dart';
import 'vis2.dart';
import 'settings.dart';

final Logger log = Logger('amount_series_page');

class AmountSeriesPage<T extends Enum, C extends Enum> extends StatefulWidget {
  const AmountSeriesPage({
    super.key,
    required this.title,
    required this.chartLibrary,
    required this.defaultRegion,
    required this.regions,
    required this.regionLabels,
    this.categories = const [],
    this.categoryLabels = const [],
  });

  final String title;
  final ChartLibrary chartLibrary;
  final T defaultRegion;
  final List<T> regions;
  final Map<T, String> regionLabels;
  final List<List<C>> categories;
  final List<Map<C, String>> categoryLabels;

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
    _selectedRegion = widget.defaultRegion;
    // Initialize with the first category
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories.first.first;
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    final data = await _api.fetchAmountSeries(
      _selectedRegion,
      _selectedCategory,
      _selectedZoom,
    );
    setState(() {
      _isLoading = false;
      _amountSeries = data;
      if (_amountSeries == null) {
        return;
      }
      _applyFilter(_selectedZoom);
    });
  }

  void _regionSelect(T region) {
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
    setState(() {
      _selectedCategory = category;
      _fetchData();
    });
  }

  void _filterData(DataRange zoomLevel) {
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
        final years =
            {
              DataRange.oneYear: 1,
              DataRange.fiveYears: 5,
              DataRange.tenYears: 10,
            }[zoomLevel]!;

        final cutoffDate = DateTime.now().subtract(Duration(days: years * 365));
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
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} Data Visualization')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Region Buttons
              OptionButtons<T>(
                selectedOption: _selectedRegion,
                values: widget.regions,
                onOptionSelected: _regionSelect,
                labels: widget.regionLabels,
              ),
              // Category Buttons
              (widget.categories.isNotEmpty)
                  ? OptionButtons<C>(
                    selectedOption: _selectedCategory!,
                    values: widget.categories[_getCategoryIndexFromRegion()],
                    onOptionSelected: _categorySelect,
                    labels:
                        widget.categoryLabels[_getCategoryIndexFromRegion()],
                  )
                  : const SizedBox(),
              // Zoom Buttons
              ZoomButtons(
                selectedZoom: _selectedZoom,
                onZoomSelected: (zoomLevel) => _filterData(zoomLevel),
              ),
            ],
          ),
          _isLoading
              ? Expanded(
                child: const Center(child: CircularProgressIndicator()),
              )
              : _amountSeries == null
              ? Expanded(child: const Center(child: Text('No data available.')))
              :
              // Line Chart
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
              ),
        ],
      ),
    );
  }
}
