# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Firefox History Scraper - A Python-based tool that searches Firefox browsing history for keywords and generates interactive HTML reports with intelligent caching.

## Key Commands

```bash
# Main executable (auto-installs dependencies via uv)
./scrape-history --help

# Basic usage examples
./scrape-history "python tutorial"                          # Search last 7 days
./scrape-history --days 30 "machine learning"               # Custom time period
./scrape-history --profile "work*" "meeting notes"          # Specific profile
./scrape-history --search-cache "python"                    # Search cache only
./scrape-history --list-profiles                            # List available profiles
./scrape-history --cache-stats                              # Show cache info
./scrape-history --clean-cache 30                           # Clean old cache entries

# Testing the script
./scrape-history --list-profiles     # Verify Firefox profile detection works
```

## Architecture

### Single-File Design
- **Main executable**: `scrape-history` - Single Python script using uv's `--script` mode
- **Dependencies**: Automatically managed via inline script metadata (no separate requirements.txt)
- **Cross-platform**: Supports macOS, Linux, Windows (including WSL)

### Core Components

**Firefox Integration (`Firefox` class)**
- Cross-platform Firefox profile detection using browserexport patterns
- Supports standard installs, Snap, Flatpak, and Windows paths
- Profile matching with glob patterns (`default*`, `work*`, etc.)

**Content Caching (`ContentCache` class)**
- SQLite-based persistent cache with proper cross-platform directories
- Uses platformdirs: `~/Library/Caches/scrape-history` (macOS), `~/.cache/scrape-history` (Linux)
- Stores scraped content with metadata (URL, title, content hash, timestamps)
- Supports cache aging and cleanup

**Async Web Scraping (`AsyncWebScraper` class)**  
- httpx + asyncio for concurrent URL processing with semaphore limiting
- Graceful encoding handling with fallback to UTF-8 replacement
- BeautifulSoup parsing with noise removal (scripts, styles, nav elements)
- Automatic retry logic and error caching

**Content Search (`KeywordSearcher` class)**
- Regex-based keyword matching with context extraction
- Performance safeguards: content truncation, match limits per keyword/URL
- Context window extraction around matches for display

**HTML Reports (`HTMLReportGenerator` class)**
- Jinja2 templating with embedded JavaScript for interactivity
- Real-time filtering, keyword highlighting, cache status indicators
- Performance limits for large result sets (100 results max for browser rendering)

### Data Flow
1. **Extract**: Firefox history → URL list with visit metadata
2. **Cache Check**: Query SQLite cache for existing content
3. **Scrape**: Async fetch missing URLs with httpx
4. **Search**: Keyword matching across all content
5. **Report**: Generate interactive HTML with results

## Development Notes

### Dependency Management
- Uses uv's script mode - dependencies declared in script header
- No separate virtual environment or package files needed
- Dependencies auto-install on first run

### Firefox Profile Handling
- Supports glob patterns for profile selection
- Multiple profile detection raises clear errors with available options
- Cross-platform path resolution with WSL detection

### Performance Considerations
- Concurrent scraping limited by semaphore (default: 10)
- Content truncation at 50KB for search performance
- HTML report limits to 100 results to prevent browser issues
- Progress bars with ETA for long operations

### Cache Management
- Content hashed by URL for deduplication
- Configurable cache age (default: 24 hours)
- Offline search capability via `--search-cache`
- Cache statistics and cleanup commands available