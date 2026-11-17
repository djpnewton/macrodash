# MacroDash

A Flutter dashboard for watching markets and the macro picture in one place:
a customisable ticker watchlist alongside M2 money supply, government debt,
bond rates, market indices, futures and market caps.

Live app: <https://macrodash.me>

## Features

- **Watchlist dashboard**: add any ticker (stocks, crypto, futures, FX), see
  the price and a sparkline, tap the change to switch between 24h and 7d, and
  drag cards to reorder them.
- **Comparison tickers**: pair two tickers on a card to compare their indexed
  price changes (for example `BTC-USD` vs `GC=F`). Existing two-ticker cards
  now show comparisons rather than ratios. Tap the card's chart or name to
  overlay additional tickers, select 7D, 1M, 1Y or YTD, and see dividend events.
  For a single-ticker card, tap its chart, then **Compare**.
  Overlays are indexed to 100 at each series' first available point in the
  common time window; they show price changes, not total returns. YTD starts
  with the first available observation of the current calendar year. Overlay
  selections are temporary and do not change the saved watchlist.
  Like the sparklines, comparison charts space observations evenly rather than
  by elapsed time. All series share the same timeline; periods with no
  observations in any series are compressed, while individual missing data is
  connected to the next observation.
  Use the share button in the comparison view to share its tickers and range
  with an indexed-chart link preview. Up to 12 tickers can be compared.
  Existing shared ratio-chart links continue to show ratios.
- **Macro charts**: M2 money supply, government debt, bond rates by term,
  market indices and futures, with zoom and shareable links.
- **Market caps**: ranked tables for several asset categories.
- **Link previews**: shared ticker and chart links render an image preview.
  Expanded dashboard sparklines can be shared with a preview of the selected
  24-hour or 7-day window.
- Light, dark and system themes, and auto-refresh when the app is reopened.

Your watchlist and settings are stored locally on the device (there are no
accounts).

## Repository layout

| Path | What it is |
| --- | --- |
| `lib/` | The Flutter app (web, Android, iOS, desktop). |
| `macrodash_server/` | [Dart Frog](https://dartfrog.vgv.dev) API that fetches and caches market and macro data. |
| `macrodash_models/` | Shared data models (JSON serialisable) used by the app and server. |
| `macrodash_preview/` | Link-preview image and share-URL helpers used by the app and server. |
| `scripts/` | Helpers for generating icons and the Open Graph image. |

## Data sources

The server aggregates data from public providers:

| Data | Provider |
| --- | --- |
| Stocks, crypto, futures, indices, ticker search | [Yahoo Finance](https://finance.yahoo.com/) |
| M2 and other series | [FRED](https://fred.stlouisfed.org/), [ECB](https://www.ecb.europa.eu/) |
| US debt | [US Treasury FiscalData](https://fiscaldata.treasury.gov/) |
| US bond rates | [US Treasury](https://home.treasury.gov/) |
| Market caps | [CoinGecko](https://www.coingecko.com/) and others |

Market data may be delayed or incomplete. MacroDash is not financial advice.

## Getting started

Requirements: the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(CI uses `3.47.x`) and, for the server, a free
[FRED API key](https://fred.stlouisfed.org/docs/api/api_key.html).

### 1. Run the server

```sh
cd macrodash_server
dart pub get
dart pub global activate dart_frog_cli   # once
FRED_API_KEY=your_key ./deploy.sh local debug
```

The server listens on `http://localhost:8080`. `./deploy.sh local release`
builds and runs the release server instead. Without `FRED_API_KEY` the
`/sov/*` routes (M2, debt, bond rates) will not return data.

### 2. Run the app

From the repository root:

```sh
flutter pub get
flutter run -d chrome     # or any other device
```

The app talks to `http://localhost:8080` by default, which matches the server
above.

### Build-time configuration

[`lib/config.dart`](lib/config.dart) contains placeholder values that the CI
workflow ([`.github/workflows/flutter.yml`](.github/workflows/flutter.yml))
replaces with `sed` before building. Do not commit the replaced values.

| Value | Placeholder | Purpose |
| --- | --- | --- |
| `gitSha` | `GIT_SHA_REPLACE` | Commit shown on the About page |
| `buildDate` | `BUILD_DATE_REPLACE` | Build time shown on the About page |
| `macrodashServerUrl` | `http://localhost:8080` | API server the app calls |
| `linkPreviewUrl` | `LINK_PREVIEW_URL_REPLACE` | Host serving link previews (falls back to the server URL) |

`clientVersion` must be kept in step with the server, which reports the
minimum client version it supports.

Server environment variables:

| Variable | Purpose |
| --- | --- |
| `FRED_API_KEY` | Required for M2, debt and bond-rate data |
| `APP_URL` | Web app URL used in link previews (default `https://macrodash.me`) |
| `PORT` | Listen port (`8080` on Fly) |

## Development

```sh
flutter test
flutter analyze
dart format lib test

# shared packages and server
cd macrodash_models  && dart pub get && dart analyze && dart test
cd macrodash_preview && dart pub get && dart analyze && dart test
cd macrodash_server  && dart pub get && dart test
```

After changing the models in `macrodash_models`, regenerate the JSON code with
`macrodash_models/build_runner.sh`.

## Deployment

The CI workflow analyses and tests everything, publishes the web app to GitHub
Pages from `master`, and creates a Netlify preview deploy. The server is
deployed to [Fly.io](https://fly.io) with
`macrodash_server/deploy.sh remote release`.

## Contributing

Issues and pull requests are welcome. Please run the checks above before
opening a pull request.
