#!/bin/bash

# URL Content Scraper
# Fetches web content from a list of URLs

set -uo pipefail

# Default values
INPUT_FILE=""
OUTPUT_DIR=""
PARALLEL_JOBS=5
TIMEOUT=10
MAX_FILE_SIZE="10M"
VERBOSE=false
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_verbose() {
    [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[DEBUG]${NC} $1" >&2
}

# Usage function
usage() {
    cat << EOF
Usage: $0 -i INPUT_FILE -o OUTPUT_DIR [options]

URL Content Scraper - Fetch web content from a list of URLs

Required:
  -i, --input FILE          Input TSV file (URL, title, timestamp)
  -o, --output DIR          Output directory for HTML files

Options:
  -p, --parallel JOBS       Number of parallel jobs (default: 5)
  -t, --timeout SECONDS     Request timeout in seconds (default: 10)
  -s, --size LIMIT          Maximum file size (default: 10M)
  -f, --force               Overwrite existing cached files
  -v, --verbose             Enable verbose output
  -h, --help                Show this help message

Examples:
  $0 -i urls.tsv -o content/
  $0 -i urls.tsv -o content/ -p 10 -t 15
  $0 -i urls.tsv -o content/ --force --verbose

Input format: URL<tab>TITLE<tab>TIMESTAMP (TSV)
Output format: {url_hash}.html files in output directory

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -s|--size)
                MAX_FILE_SIZE="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$INPUT_FILE" ]]; then
        log_error "Input file is required. Use -i or --input option."
        usage
        exit 1
    fi

    if [[ -z "$OUTPUT_DIR" ]]; then
        log_error "Output directory is required. Use -o or --output option."
        usage
        exit 1
    fi

    # Validate files and directories
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "Input file not found: $INPUT_FILE"
        exit 1
    fi

    # Validate numeric arguments
    if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ "$PARALLEL_JOBS" -lt 1 ]] || [[ "$PARALLEL_JOBS" -gt 20 ]]; then
        log_error "Parallel jobs must be between 1 and 20."
        exit 1
    fi

    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT" -lt 1 ]]; then
        log_error "Timeout must be a positive integer."
        exit 1
    fi
}

# Generate cache filename from URL
get_cache_filename() {
    local url="$1"
    echo -n "$url" | shasum -a 256 | cut -d' ' -f1
}

# Check dependencies
check_dependencies() {
    local deps=("curl" "shasum")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
}

# Progress tracking
update_progress() {
    local current="$1"
    local total="$2"
    local percent=$((current * 100 / total))
    printf "\r${BLUE}[INFO]${NC} Progress: %d/%d (%d%%)" "$current" "$total" "$percent" >&2
    [[ "$current" -eq "$total" ]] && echo >&2
}

# Scrape single URL
scrape_url() {
    local url="$1"
    local cache_file="$2"
    
    log_verbose "Scraping: $url"
    
    # Use curl to fetch content
    if curl -s -L \
        --max-time "$TIMEOUT" \
        --connect-timeout 5 \
        --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        --header "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        --header "Accept-Language: en-US,en;q=0.9" \
        --max-filesize "$MAX_FILE_SIZE" \
        --output "$cache_file" \
        "$url" 2>/dev/null; then
        
        # Verify file was created and has content
        if [[ -f "$cache_file" ]] && [[ -s "$cache_file" ]]; then
            log_verbose "Successfully scraped: $url"
            return 0
        else
            log_verbose "Empty response for: $url"
            rm -f "$cache_file"
            return 1
        fi
    else
        log_verbose "Failed to scrape: $url"
        rm -f "$cache_file"
        return 1
    fi
}

# Process URLs from TSV file
process_urls() {
    local total_urls
    total_urls=$(wc -l < "$INPUT_FILE")
    
    log_info "Processing $total_urls URLs from: $INPUT_FILE"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Parallel jobs: $PARALLEL_JOBS, Timeout: ${TIMEOUT}s"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local current=0
    local success_count=0
    local cache_hits=0
    local pids=()
    
    while IFS=$'\t' read -r url title timestamp || [[ -n "$url" ]]; do
        # Skip empty lines
        [[ -z "$url" ]] && continue
        
        ((current++))
        
        # Generate cache filename
        local cache_filename
        cache_filename=$(get_cache_filename "$url")
        local cache_file="$OUTPUT_DIR/$cache_filename.html"
        
        # Check if file already exists (unless force flag is set)
        if [[ -f "$cache_file" ]] && [[ "$FORCE" != true ]]; then
            log_verbose "Using cached file for: $url"
            ((cache_hits++))
            ((success_count++))
            update_progress "$current" "$total_urls"
            continue
        fi
        
        # Scrape URL in background if parallel jobs available
        if [[ ${#pids[@]} -ge $PARALLEL_JOBS ]]; then
            # Wait for any background job to complete
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    # Job finished, check result but don't let failures affect the script
                    wait "${pids[i]}" && ((success_count++)) || true
                    unset "pids[i]"
                    break
                fi
            done
            # Rebuild array to remove unset elements
            pids=("${pids[@]}")
        fi
        
        # Start scraping in background
        {
            scrape_url "$url" "$cache_file"
        } &
        pids+=($!)
        
        update_progress "$current" "$total_urls"
        
        # Small delay to be respectful to servers
        sleep 0.1
        
    done < "$INPUT_FILE"
    
    # Wait for all background jobs to complete
    for pid in "${pids[@]}"; do
        # Don't let individual job failures affect the script
        wait "$pid" && ((success_count++)) || true
    done
    
    update_progress "$total_urls" "$total_urls"
    
    log_success "Scraping completed: $success_count/$total_urls URLs successfully scraped"
    
    if [[ "$cache_hits" -gt 0 ]]; then
        log_info "Cache hits: $cache_hits (use --force to re-scrape cached files)"
    fi
    
    # Report final statistics
    local failed_count=$((total_urls - success_count))
    if [[ "$failed_count" -gt 0 ]]; then
        log_warn "$failed_count URLs failed to scrape"
    fi
    
    # List output directory contents
    local file_count
    file_count=$(find "$OUTPUT_DIR" -name "*.html" | wc -l)
    log_info "Content directory contains $file_count HTML files"
}

# Main function
main() {
    parse_arguments "$@"
    check_dependencies
    
    log_info "URL Content Scraper starting..."
    log_verbose "Configuration: parallel=$PARALLEL_JOBS, timeout=$TIMEOUT, size=$MAX_FILE_SIZE, force=$FORCE"
    
    process_urls
    
    # Only fail if we got absolutely no results
    local file_count
    file_count=$(find "$OUTPUT_DIR" -name "*.html" | wc -l)
    if [[ "$file_count" -eq 0 ]]; then
        log_error "No URLs were successfully scraped"
        exit 1
    fi
    
    log_success "URL scraping completed successfully!"
    
    # Explicit success exit - don't let background job failures affect our exit code
    exit 0
}

# Execute main function
main "$@"