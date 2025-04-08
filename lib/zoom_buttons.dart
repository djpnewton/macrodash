import 'package:flutter/material.dart';

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
          ElevatedButton(
            onPressed: () => onZoomSelected(ZoomLevel.oneYear),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedZoom == ZoomLevel.oneYear
                      ? Colors.blue
                      : Colors.grey, // Highlight selected button
            ),
            child: const Text(
              '1Y',
              style: TextStyle(color: Colors.white), // Set text color to white
            ),
          ),
          const SizedBox(width: 8), // Add spacing between buttons
          ElevatedButton(
            onPressed: () => onZoomSelected(ZoomLevel.fiveYears),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedZoom == ZoomLevel.fiveYears
                      ? Colors.blue
                      : Colors.grey, // Highlight selected button
            ),
            child: const Text(
              '5Y',
              style: TextStyle(color: Colors.white), // Set text color to white
            ),
          ),
          const SizedBox(width: 8), // Add spacing between buttons
          ElevatedButton(
            onPressed: () => onZoomSelected(ZoomLevel.tenYears),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedZoom == ZoomLevel.tenYears
                      ? Colors.blue
                      : Colors.grey, // Highlight selected button
            ),
            child: const Text(
              '10Y',
              style: TextStyle(color: Colors.white), // Set text color to white
            ),
          ),
          const SizedBox(width: 8), // Add spacing between buttons
          ElevatedButton(
            onPressed: () => onZoomSelected(ZoomLevel.max),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedZoom == ZoomLevel.max
                      ? Colors.blue
                      : Colors.grey, // Highlight selected button
            ),
            child: const Text(
              'Max',
              style: TextStyle(color: Colors.white), // Set text color to white
            ),
          ),
        ],
      ),
    );
  }
}
