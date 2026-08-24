# AGENTS.md

Omarchy (Quickshell) bar-widget plugin that displays real-time stock, ETF, and crypto quotes, intraday sparklines, portfolio tracking, analyst recommendations, and news using Finnhub. NOT a Node app — the UI runtime is QML / Quickshell, backed by an asynchronous Ruby daemon.

## Architecture

- `manifest.json`: Plugin descriptor; `entryPoints.barWidget` = `BarWidget.qml`, `kinds: ["bar-widget"]`.
- `BarWidget.qml`: Top bar widget (~233 lines). Renders the compact rotating ticker and manages the background Ruby daemon process lifecycle (`Process` + `SplitParser`).
- `Panel.qml`: Interactive slide-out financial dashboard (~1,112 lines). Renders portfolio totals, watchlist cards with Canvas sparklines, 52-week bullet range sliders, analyst consensus distribution bars, financial metrics, and live news feeds.
- `BarWidgetModel.js`: Pure JavaScript helper for timestamp formatting and math utilities.
- `daemon/`: Pure Ruby background engine (Ruby 4.0+):
  - `fetcher.rb`: CLI daemon entrypoint reading stdin commands and running cyclic timers.
  - `daemon.rb`: Asynchronous orchestrator coordinating quotes, profiles, recommendations, and news.
  - `finnhub_client.rb`: HTTP client with token authentication, rate limit handling, and status code translation.
  - `cache.rb`: Thread-safe in-memory TTL caching with atomic read/write synchronization.
  - `quote_fetcher.rb`: Real-time quote polling and discrete anchor point sparklines.
  - `profile_fetcher.rb`: Company metrics, 52-week price statistics, and market capitalization.
  - `news_fetcher.rb`: Recent company headlines with relative timestamps.
  - `recommendation_fetcher.rb`: Aggregated Wall Street analyst consensus ratings.
  - `formatter.rb`: High-performance string formatting, currency symbols, and privacy stealth mode.

## Critical Runtime Constraints

- **Finnhub Free Tier Only**: Only 100% free endpoints (`/quote`, `/stock/profile2`, `/stock/metric`, `/company-news`, `/stock/recommendation`) may be queried. Paywalled endpoints (`/stock/candle`, `/news-sentiment`) must never be called.
- **Rate Limit Pacing**: Finnhub free tier is strictly capped at 60 calls/minute. All requests must go through `Cache` with appropriate TTLs and sequential ticker pacing (`TICKER_CYCLE_DELAY = 0.2s`).
- **Data Formatting Boundary**: The Ruby daemon pre-formats all prices, deltas, market caps, and tooltips and dispatches them over stdout as JSON lines; QML renders strings directly without heavy client-side business logic.
- **QML V4 Engine**: Dependency-free pure JavaScript only. No Node/npm packages.

## Workflow Conventions

- Contributions follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `ci:`) and a strictly linear history (rebase, no merge commits).
- Always verify all suites pass before committing:
  `bundle exec rake && bundle exec rubocop && qmllint Panel.qml BarWidget.qml`
- Widget settings are configured via `omarchy bar set tobiasz-p.market-tracker <key> <value>`.

## Releasing

- Merge all PRs **before** tagging. The marketplace verifies exact commit snapshots, which are immutable once published.
- Semver from Conventional Commits: `fix:` → patch, `feat:` → minor, breaking → major.
- Bump `version` in `manifest.json`, commit as `chore: bump version to X.Y.Z`, then tag without the `v` prefix and push both:
  `git tag -a X.Y.Z -m "X.Y.Z" && git push origin main X.Y.Z`
- Create the GitHub release:
  `gh release create X.Y.Z --title "X.Y.Z" --notes "..."`
- Ask for marketplace verification with a `[Verify]` issue on `HANCORE-linux/omarchy-plugin-marketplace`.
