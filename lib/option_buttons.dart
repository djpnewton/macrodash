import 'package:flutter/material.dart';

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
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Colors.blue : Colors.grey, // Highlight selected button
        fixedSize: const Size(30, 30), // Set fixed size for square buttons
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Slightly rounded corners
        ),
        padding: EdgeInsets.zero, // Remove extra padding
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ), // Adjust font size
      ),
    );
  }
}

enum ZoomLevel { oneYear, fiveYears, tenYears, max }

class ZoomButtons extends StatelessWidget {
  final ZoomLevel selectedZoom;
  final Function(ZoomLevel) onZoomSelected;

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
            isSelected: selectedZoom == ZoomLevel.oneYear,
            onPressed: () => onZoomSelected(ZoomLevel.oneYear),
          ),
          const SizedBox(width: 1), // Add spacing between buttons
          OptionButton(
            label: '5Y',
            isSelected: selectedZoom == ZoomLevel.fiveYears,
            onPressed: () => onZoomSelected(ZoomLevel.fiveYears),
          ),
          const SizedBox(width: 1), // Add spacing between buttons
          OptionButton(
            label: '10Y',
            isSelected: selectedZoom == ZoomLevel.tenYears,
            onPressed: () => onZoomSelected(ZoomLevel.tenYears),
          ),
          const SizedBox(width: 1), // Add spacing between buttons
          OptionButton(
            label: 'Max',
            isSelected: selectedZoom == ZoomLevel.max,
            onPressed: () => onZoomSelected(ZoomLevel.max),
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
