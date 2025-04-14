import 'package:flutter/material.dart';

import 'package:macrodash_models/models.dart';

class OptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const OptionButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access the current theme

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
        padding: EdgeInsets.zero,
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

  const ZoomButtons({
    super.key,
    required this.selectedZoom,
    required this.onZoomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the right
        children: [
          OptionButton(
            label: '1Y',
            isSelected: selectedZoom == DataRange.oneYear,
            onPressed: () => onZoomSelected(DataRange.oneYear),
          ),
          const SizedBox(width: 1), // Add spacing between buttons
          OptionButton(
            label: '5Y',
            isSelected: selectedZoom == DataRange.fiveYears,
            onPressed: () => onZoomSelected(DataRange.fiveYears),
          ),
          const SizedBox(width: 1), // Add spacing between buttons
          OptionButton(
            label: '10Y',
            isSelected: selectedZoom == DataRange.tenYears,
            onPressed: () => onZoomSelected(DataRange.tenYears),
          ),
          const SizedBox(width: 1), // Add spacing between buttons
          OptionButton(
            label: 'Max',
            isSelected: selectedZoom == DataRange.max,
            onPressed: () => onZoomSelected(DataRange.max),
          ),
        ],
      ),
    );
  }
}

class OptionButtons<T extends Enum> extends StatelessWidget {
  final T selectedOption;
  final List<T> values;
  final Function(T) onOptionSelected;
  final Map<T, String> labels;

  const OptionButtons({
    super.key,
    required this.selectedOption,
    required this.values,
    required this.onOptionSelected,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
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
}
