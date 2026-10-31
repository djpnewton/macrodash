import 'dart:convert';

/// Escapes [value] for use in an HTML attribute.
String escapeHtmlAttribute(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

/// Server-rendered Open Graph page that link unfurlers read.
///
/// Scrapers do not run JavaScript, so the tags are rendered here. Browsers are
/// redirected into the app via [appLink].
String renderLinkPreviewHtml({
  required String title,
  required String description,
  required String shareUrl,
  required String imageUrl,
  required String imageAlt,
  required String appLink,
}) {
  final escapedTitle = escapeHtmlAttribute(title);
  final escapedDescription = escapeHtmlAttribute(description);
  final escapedShareUrl = escapeHtmlAttribute(shareUrl);
  final escapedImageUrl = escapeHtmlAttribute(imageUrl);
  final escapedImageAlt = escapeHtmlAttribute(imageAlt);
  final escapedAppLink = escapeHtmlAttribute(appLink);

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$escapedTitle — MacroDash</title>
<meta name="description" content="$escapedDescription">
<meta property="og:type" content="website">
<meta property="og:site_name" content="MacroDash">
<meta property="og:title" content="$escapedTitle">
<meta property="og:description" content="$escapedDescription">
<meta property="og:url" content="$escapedShareUrl">
<meta property="og:image" content="$escapedImageUrl">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="$escapedImageAlt">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="$escapedTitle">
<meta name="twitter:description" content="$escapedDescription">
<meta name="twitter:image" content="$escapedImageUrl">
<meta name="twitter:image:alt" content="$escapedImageAlt">
<meta name="theme-color" content="#0B1B33">
<meta http-equiv="refresh" content="0; url=$escapedAppLink">
<script>window.location.replace(${jsonEncode(appLink)});</script>
</head>
<body>
<p>Opening MacroDash… <a href="$escapedAppLink">Continue to the chart</a></p>
</body>
</html>
''';
}
