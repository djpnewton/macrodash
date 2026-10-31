import 'package:flutter/material.dart';

/// The git SHA of source of the current build
const String gitSha = 'GIT_SHA_REPLACE';

/// The date when the software was built
const String buildDate = 'BUILD_DATE_REPLACE';

/// The URL of the MacroDash server
const String macrodashServerUrl = 'http://localhost:8080';

/// Host that serves the per-ticker link previews (Open Graph pages + images)
const String linkPreviewUrl = 'LINK_PREVIEW_URL_REPLACE';

/// The web app's canonical URL, used for links that are not ticker previews.
const String macrodashWebUrl = 'https://macrodash.me';

/// Resolves the link preview URL, falling back to the MacroDash server URL if necessary
String get resolvedLinkPreviewUrl =>
    linkPreviewUrl.startsWith('http') ? linkPreviewUrl : macrodashServerUrl;

/// Client version, used to ensure we match the servers api version
const int clientVersion = 11;

/// Theme mode used until one is chosen in settings.
const ThemeMode defaultThemeMode = ThemeMode.system;

/// The different pages of the app
enum AppPage {
  ticker,
  m2,
  debt,
  bondRates,
  indices,
  futures,
  marketCap,
  settings,
  about,
}

/// Titles for each page of the app
const _pageTitles = {
  AppPage.ticker: 'Ticker',
  AppPage.m2: 'M2',
  AppPage.debt: 'Debt',
  AppPage.bondRates: 'Bond Rates',
  AppPage.indices: 'Indices',
  AppPage.futures: 'Futures',
  AppPage.marketCap: 'Market Cap',
  AppPage.settings: 'Settings',
  AppPage.about: 'About',
};

String pageTitle(AppPage page) {
  return _pageTitles[page] ?? 'Unknown';
}
