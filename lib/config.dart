const String gitSha = 'GIT_SHA_REPLACE';
const String buildDate = 'BUILD_DATE_REPLACE';
const String macrodashServerUrl = 'http://localhost:8080';
const int clientVersion = 9;

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
