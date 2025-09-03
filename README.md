# Firefox History Scraper

A fast, caching-enabled tool that searches your Firefox browsing history for keywords and generates interactive HTML reports.

## Features

- **Smart Caching**: Scrapes web pages once, reuses cached content for future searches
- **Cross-Platform**: Works on macOS, Linux, and Windows (including WSL)
- **Flexible Profile Support**: Use glob patterns to match Firefox profiles (`default*`, `work*`, etc.)
- **Interactive Reports**: HTML output with keyword highlighting, filtering, and search
- **Performance Optimized**: Handles large datasets with progress tracking and browser safeguards

## Quick Start

```bash
# Basic search (last 7 days)
./scrape-history "python tutorial"

# Multiple keywords  
./scrape-history "machine learning" "neural networks" 

# Custom time period and profile
./scrape-history --days 30 --profile "work*" "meeting notes"

# Exclude certain sites
./scrape-history --exclude "google.com" --exclude "reddit.com" "javascript"
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

## Output

Generates an interactive HTML report (`search_results.html`) with:
- Clickable links to original pages
- Keyword highlighting in context snippets  
- Cache status indicators (fresh vs cached)
- Real-time filtering and search
- Visit timestamps and metadata

## Performance

- **Parallel Scraping**: Processes multiple URLs concurrently
- **Smart Caching**: Reuses content across searches (saves bandwidth)
- **Large Dataset Handling**: Automatically limits HTML output for browser performance
- **Progress Tracking**: Real-time progress bars with ETA and statistics

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
| `--profile PATTERN` | Firefox profile glob pattern |
| `--max-urls N` | Limit to N URLs (default: 1000, 0=unlimited) |
| `--exclude PATTERN` | Skip URLs matching pattern |
| `--output FILE` | HTML report filename |
| `--cache-dir DIR` | Custom cache directory |

## Examples

```bash
# Research project tracking
./scrape-history --days 14 "machine learning" "pytorch" --output ml_research.html

# Meeting notes search  
./scrape-history --profile "work*" "standup" "retrospective" "planning"

# Content cleanup
./scrape-history --exclude "*.google.com" --exclude "*/admin/*" "documentation"

# Quick cache-only search
./scrape-history --search-cache "kubernetes" "docker"
```

## Cache Location

- **macOS**: `~/Library/Caches/scrape-history`
- **Linux**: `~/.cache/scrape-history` 
- **Windows**: `%LOCALAPPDATA%\scrape-history`