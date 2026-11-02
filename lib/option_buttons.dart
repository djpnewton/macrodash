import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import 'config.dart';
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
    DataRange.oneMonth,
    DataRange.threeMonths,
    DataRange.sixMonths,
    DataRange.oneYear,
    DataRange.fiveYears,
    DataRange.tenYears,
    DataRange.max,
  ];
  static const labels = {
    DataRange.oneMonth: '1M',
    DataRange.threeMonths: '3M',
    DataRange.sixMonths: '6M',
    DataRange.oneYear: '1Y',
    DataRange.fiveYears: '5Y',
    DataRange.tenYears: '10Y',
    DataRange.max: 'Max',
  };
  static const _labelsLong = {
    DataRange.oneMonth: '1 Month',
    DataRange.threeMonths: '3 Months',
    DataRange.sixMonths: '6 Months',
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
      labels: labels,
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

enum ShareMethod { copy, share }

/// The 1200x630 chart image a share link unfurls to
class SharePreviewImage extends StatelessWidget {
  const SharePreviewImage({super.key, required this.url, this.imageProvider});

  final String url;

  /// Overrides the network image, so tests can drive the loaded state without
  /// a server.
  @visibleForTesting
  final ImageProvider? imageProvider;

  static const double _aspectRatio = 1200 / 630;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget placeholder({required bool loading}) => ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child:
            loading
                ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preview unavailable',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Image(
            image: imageProvider ?? NetworkImage(url),
            fit: BoxFit.cover,
            semanticLabel: 'Link preview image',
            // The server renders the PNG on demand, so the wait is visible.
            // `frameBuilder` is used rather than `loadingBuilder` because the
            // web engine never reports byte progress: `loadingBuilder` would
            // get a null progress for the whole load and show a blank frame.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              return placeholder(loading: true);
            },
            errorBuilder:
                (context, error, stackTrace) => placeholder(loading: false),
          ),
        ),
      ),
    );
  }
}

/// a share button implementing optionbutton
class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.uri, this.queryParams});
  final Uri uri;
  final Map<String, String>? queryParams;

  /// Ticker and dashboard pages point at the preview host so social apps can
  /// unfurl a chart; everything else falls back to the plain app URL.
  String _buildShareUri(Map<String, String> params) {
    final ticker1 = params.remove('ticker1');
    if (ticker1 != null && ticker1.isNotEmpty) {
      return tickerShareUrl(
        previewUrl: resolvedLinkPreviewUrl,
        ticker1: ticker1,
        params: params,
      );
    }
    final page = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (isPreviewPage(page)) {
      return pageShareUrl(
        previewUrl: resolvedLinkPreviewUrl,
        page: page,
        params: params,
      );
    }
    // manually construct the share URI to conform to flutter routing
    // uris where the query is after the fragment
    final query = Uri(queryParameters: params).query;
    return '$macrodashWebUrl/#${uri.path}${query.isEmpty ? '' : '?$query'}';
  }

  /// The chart image recipients will see unfurled, or null when the page has no
  /// server-rendered preview.
  String? _buildPreviewImageUri(Map<String, String> params) {
    final ticker1 = params.remove('ticker1');
    if (ticker1 != null && ticker1.isNotEmpty) {
      return tickerPreviewImageUrl(
        previewUrl: resolvedLinkPreviewUrl,
        ticker1: ticker1,
        params: params,
      );
    }
    final page = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (isPreviewPage(page)) {
      return pagePreviewImageUrl(
        previewUrl: resolvedLinkPreviewUrl,
        page: page,
        params: params,
      );
    }
    return null;
  }

  void _share(BuildContext context) {
    final shareUri = _buildShareUri({...?queryParams});
    final previewImageUri = _buildPreviewImageUri({...?queryParams});

    showDialog<ShareMethod>(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: Text('Select how you want to share the link:'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (previewImageUri != null) ...[
                SharePreviewImage(url: previewImageUri),
                const SizedBox(height: 16),
              ],
              Text(shareUri.toString()),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  TextButton.icon(
                    label: const Text('Copy Link'),
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: shareUri.toString()),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Link copied to clipboard')),
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                  if (isWebMobile()) ...[
                    TextButton.icon(
                      label: const Text('Share Link'),
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        SharePlus.instance.share(ShareParams(text: shareUri));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Link shared')));
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OptionButton(
      label: '',
      isSelected: false,
      onPressed: () => _share(context),
      icon: Icons.share,
    );
  }
}
