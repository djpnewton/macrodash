import 'package:flutter/material.dart';

import 'package:macrodash_models/models.dart';

import 'helper.dart';

class OptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final IconData? icon;

  const OptionButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access the current theme
    if (icon != null) {
      return Container(
        width: 35,
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? theme
                      .colorScheme
                      .primary // Use primary color for selected
                  : theme
                      .colorScheme
                      .surfaceContainer, // Use surface color for unselected
          borderRadius: BorderRadius.circular(4), // Slightly rounded corners
        ),
        child: IconButton(
          padding: EdgeInsets.all(0),
          icon: Icon(icon),
          onPressed: onPressed,
          color:
              isSelected
                  ? theme
                      .colorScheme
                      .onPrimary // Text color for selected
                  : theme.colorScheme.onSurface, // Text color for unselected
          iconSize: 20,
        ),
      );
    }
    // If no icon is provided, use a TextButton
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor:
            isSelected
                ? theme
                    .colorScheme
                    .primary // Use primary color for selected
                : theme
                    .colorScheme
                    .surfaceContainer, // Use surface color for unselected
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Slightly rounded corners
        ),
        minimumSize: Size.square(35),
        padding: EdgeInsets.symmetric(horizontal: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              isSelected
                  ? theme
                      .colorScheme
                      .onPrimary // Text color for selected
                  : theme.colorScheme.onSurface, // Text color for unselected
          fontSize: 10,
          //height: 0.1,
        ),
      ),
    );
  }
}

class ZoomButtons extends StatelessWidget {
  final DataRange selectedZoom;
  final Function(DataRange) onZoomSelected;
  final bool popout;

  static const _ranges = [
    DataRange.oneYear,
    DataRange.fiveYears,
    DataRange.tenYears,
    DataRange.max,
  ];
  static const _labels = {
    DataRange.oneYear: '1Y',
    DataRange.fiveYears: '5Y',
    DataRange.tenYears: '10Y',
    DataRange.max: 'Max',
  };
  static const _labelsLong = {
    DataRange.oneYear: '1 Year',
    DataRange.fiveYears: '5 Years',
    DataRange.tenYears: '10 Years',
    DataRange.max: 'Max',
  };

  const ZoomButtons({
    super.key,
    required this.selectedZoom,
    required this.onZoomSelected,
    this.popout = false,
  });

  Widget _buildPopout(BuildContext context) {
    return OptionButtons<DataRange>(
      popoutTitle: 'Range',
      selectedOption: selectedZoom,
      values: _ranges,
      onOptionSelected: (value) => onZoomSelected(value),
      labels: _labelsLong,
      popout: true,
    );
  }

  Widget _buildRow(BuildContext context) {
    return OptionButtons<DataRange>(
      popoutTitle: 'Range',
      selectedOption: selectedZoom,
      values: _ranges,
      onOptionSelected: (value) => onZoomSelected(value),
      labels: _labels,
      popout: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (popout) return _buildPopout(context);
    return _buildRow(context);
  }
}

class OptionButtons<T extends Enum> extends StatelessWidget {
  final String popoutTitle;
  final T selectedOption;
  final List<T> values;
  final Function(T) onOptionSelected;
  final Map<T, String> labels;
  final bool popout;

  static const _padding = 2.0;

  const OptionButtons({
    super.key,
    required this.popoutTitle,
    required this.selectedOption,
    required this.values,
    required this.onOptionSelected,
    required this.labels,
    this.popout = false,
  });

  Widget _buildPopout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_padding),
      child: Row(
        children: [
          Text('$popoutTitle:', style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 2),
          OptionButton(
            label: labels[selectedOption] ?? selectedOption.name,
            isSelected: true,
            onPressed: () {
              showDialog<T>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Select $popoutTitle'),
                    content: OptionButtons<T>(
                      popoutTitle: popoutTitle,
                      selectedOption: selectedOption,
                      values: values,
                      onOptionSelected: (value) {
                        Navigator.of(context).pop();
                        onOptionSelected(value);
                      },
                      labels: labels,
                      popout: false,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_padding),
      child: Row(
        children:
            values.map((e) {
              final isLast = e == values.last; // Check if it's the last button
              return Row(
                children: [
                  OptionButton(
                    label:
                        labels.containsKey(e)
                            ? labels[e]!
                            : e.name.toUpperCase(),
                    isSelected: selectedOption == e,
                    onPressed: () => onOptionSelected(e),
                  ),
                  if (!isLast) // Add a 1-pixel box unless it's the last button
                    const SizedBox(width: 1),
                ],
              );
            }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (popout) return _buildPopout(context);
    return _buildRow(context);
  }
}

/// a fullscreen button implementing optionbutton
class FullscreenButton extends StatelessWidget {
  const FullscreenButton({super.key});

  void _toggleFullscreen() {
    if (isFullscreen()) {
      exitFullscreen();
    } else {
      enterFullscreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OptionButton(
      label: '',
      isSelected: isFullscreen(),
      onPressed: () => _toggleFullscreen(),
      icon: isFullscreen() ? Icons.fullscreen_exit : Icons.fullscreen,
    );
  }
}
