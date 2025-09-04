# Firefox History Scraper

A fast, caching-enabled tool that searches your Firefox browsing history for keywords and generates interactive HTML reports with real-time exclusion management.

## Features

- **🚫 Interactive Exclusion System**: Click to exclude domains/URLs directly in reports, with automatic command generation for next run
- **⚡ Smart Caching**: Scrapes web pages once, reuses cached content for future searches
- **🌍 Cross-Platform**: Works on macOS, Linux, and Windows (including WSL)  
- **📁 Flexible Profile Support**: Use glob patterns to match Firefox profiles (`default*`, `work*`, etc.)
- **📊 Interactive Reports**: HTML output with keyword highlighting, filtering, exclusion management, and command reconstruction
- **🚀 High-Performance Scraping**: Concurrent URL processing with configurable limits (10-50+ concurrent requests)
- **📈 Progress Tracking**: Real-time progress bars with ETA, cache hit rates, and statistics

## Quick Start

```bash
# Basic search (last 7 days)
./scrape-history "python tutorial"

# High-performance search with concurrent scraping
./scrape-history --max-concurrent 25 "machine learning"

# Multiple keywords with custom time period
./scrape-history --days 30 --profile "work*" "meeting notes"

# Pre-exclude sites (or use interactive exclusion in the HTML report)
./scrape-history --exclude "reddit.com" --exclude "youtube.com" "javascript"
```

## Installation

Requires Python 3.12+ and uses [uv](https://docs.astral.sh/uv/) for dependency management:

```bash
# Clone and run (dependencies auto-installed)
git clone <repo-url>
cd history-scrape
./scrape-history --help
```

## Common Usage

```bash
# List available Firefox profiles
./scrape-history --list-profiles

# Search specific profile with more URLs
./scrape-history --profile "customization*" --max-urls 200 "tutorial"

# Search only cached content (offline)
./scrape-history --search-cache "python"

# Force refresh cache for recent pages
./scrape-history --refresh-cache --days 3 "news"

# Cache management
./scrape-history --cache-stats
./scrape-history --clean-cache 30  # Remove entries older than 30 days
```

## Interactive Exclusion System 🚫

The HTML reports now include a powerful exclusion management system:

### Real-Time Exclusion
- **🚫 Domain**: Click to exclude entire domains (e.g., `reddit.com`)
- **❌ URL**: Click to exclude specific URLs
- **Live filtering**: Excluded results disappear immediately
- **Visual indicators**: Excluded results are grayed out when toggled visible

### Smart Command Generation  
- **Complete preservation**: Maintains all original flags (`--days`, `--max-concurrent`, `--profile`, etc.)
- **Auto-reconstruction**: Generates ready-to-run commands with new exclusions
- **One-click copy**: Copy the complete command to clipboard
- **Persistent exclusions**: Exclusions survive browser refreshes via localStorage

### Workflow Example
1. Run initial search: `./scrape-history "python tutorial"`
2. Open HTML report and exclude unwanted domains by clicking 🚫 buttons
3. Copy the reconstructed command (e.g., `./scrape-history --exclude "reddit.com" --exclude "youtube.com" "python tutorial"`)
4. Run refined search with automatic exclusions

## Output

Generates an interactive HTML report (`search_results.html`) with:
- **Exclusion Management**: Real-time domain/URL exclusion with command generation
- **Clickable links**: Direct access to original pages
- **Keyword highlighting**: Context snippets with highlighted search terms
- **Cache indicators**: Visual distinction between fresh and cached content
- **Advanced filtering**: Real-time search and result filtering
- **Result counters**: Shows visible/total/excluded result counts
- **Visit metadata**: Timestamps, visit frequency, and scrape status

## Performance 🚀

- **Concurrent Scraping**: Configurable parallel processing (default: 10, recommended: 20-30+ for fast networks)
- **Smart Caching**: Persistent SQLite cache reuses content across searches
- **Async Architecture**: httpx + asyncio for maximum throughput
- **Progress Tracking**: Real-time progress bars showing cache hits, fresh scrapes, and errors
- **Browser Optimization**: Automatically limits HTML report size for browser performance
- **Bandwidth Efficiency**: Only scrapes new/updated content, respects cache age settings

## Firefox Profile Detection

Uses browserexport-style detection supporting:
- **Standard installations**: `~/.mozilla/firefox/`, `~/Library/Application Support/Firefox/`
- **Snap packages**: `~/snap/firefox/common/.mozilla/firefox/`
- **Flatpak**: `~/.var/app/org.mozilla.firefox/.mozilla/firefox/`
- **Windows**: `%LOCALAPPDATA%` and `%APPDATA%` paths

## Options

| Option | Description |
|--------|-------------|
| `--days N` | Look back N days (default: 7) |
| `--max-concurrent N` | Concurrent HTTP requests (default: 10, try 20-30 for faster scraping) |
| `--profile PATTERN` | Firefox profile glob pattern (supports `*`, `default*`, `work*`) |
| `--max-urls N` | Limit fresh URLs to scrape (default: 1000, 0=unlimited, cached URLs don't count) |
| `--exclude PATTERN` | Skip URLs matching pattern (domains, extensions, or custom patterns) |
| `--include PATTERN` | Include URLs matching pattern (overrides exclusions) |
| `--no-default-exclusions` | Disable built-in exclusions for social media, ads, etc. |
| `--output FILE` | HTML report filename (default: search_results.html) |
| `--max-cache-age N` | Max cache age in hours (default: 24) |
| `--cache-dir DIR` | Custom cache directory |
| `--search-cache` | Search only cached content (offline mode) |
| `--refresh-cache` | Force refresh of all URLs |
| `--list-profiles` | Show available Firefox profiles |
| `--cache-stats` | Display cache statistics |
| `--clean-cache N` | Remove cache entries older than N days |

## Examples

```bash
# High-performance research with interactive exclusion
./scrape-history --max-concurrent 25 --days 14 "machine learning" "pytorch" --output ml_research.html
# Then use the HTML report to exclude unwanted domains and copy the refined command

# Work meeting search across specific profile
./scrape-history --profile "work*" --max-concurrent 20 "standup" "retrospective" "planning"

# Fast cache-only search (offline)
./scrape-history --search-cache --max-concurrent 30 "kubernetes" "docker"

# Clean content search with custom exclusions
./scrape-history --exclude "reddit.com" --exclude "youtube.com" --include "github.com" "documentation"

# Performance-optimized recent content refresh
./scrape-history --refresh-cache --days 3 --max-concurrent 50 --max-urls 500 "tech news"

# Cache management workflow
./scrape-history --cache-stats                    # Check cache status
./scrape-history --clean-cache 30                # Clean old entries
./scrape-history --search-cache "python"         # Search cleaned cache
```

## Cache Location

- **macOS**: `~/Library/Caches/scrape-history`
- **Linux**: `~/.cache/scrape-history` 
- **Windows**: `%LOCALAPPDATA%\scrape-history`