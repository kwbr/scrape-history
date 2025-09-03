#!/bin/bash

# Firefox URL Extractor
# Extracts and filters URLs from Firefox browsing history

set -uo pipefail

# Default values
DAYS=7
EXCLUDE_PATTERNS=()
OUTPUT_FILE=""
VERBOSE=false

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
Usage: $0 [options]

Firefox URL Extractor - Extract URLs from Firefox browsing history

Options:
  -d, --days DAYS           Number of days back to search (default: 7)
  -e, --exclude PATTERN     URL pattern to exclude (can be used multiple times)
  -o, --output FILE         Output TSV file (default: stdout)
  -v, --verbose             Enable verbose output
  -h, --help                Show this help message

Examples:
  $0 -d 14 -o urls.tsv
  $0 -d 7 -e "*github*" -e "*.google.com" -o filtered_urls.tsv
  $0 -d 30 -v > history_urls.tsv

Output format: URL<tab>TITLE<tab>TIMESTAMP (TSV)

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--days)
                DAYS="$2"
                shift 2
                ;;
            -e|--exclude)
                EXCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
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

    # Validate numeric arguments
    if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
        log_error "Days must be a positive integer."
        exit 1
    fi
}

# Find Firefox profile directory
find_firefox_profile() {
    local firefox_profiles_dir
    local profiles_ini
    
    # macOS path
    if [[ "$OSTYPE" == "darwin"* ]]; then
        firefox_profiles_dir="$HOME/Library/Application Support/Firefox"
    # Linux path
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        firefox_profiles_dir="$HOME/.mozilla/firefox"
    # Windows (if running in WSL/Cygwin)
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
        firefox_profiles_dir="$APPDATA/Mozilla/Firefox"
    else
        log_error "Unsupported operating system: $OSTYPE"
        return 1
    fi
    
    if [[ ! -d "$firefox_profiles_dir" ]]; then
        log_error "Firefox profile directory not found: $firefox_profiles_dir"
        return 1
    fi
    
    profiles_ini="$firefox_profiles_dir/profiles.ini"
    if [[ ! -f "$profiles_ini" ]]; then
        log_error "Firefox profiles.ini not found: $profiles_ini"
        return 1
    fi
    
    # Find default profile from profiles.ini (modern Firefox format)
    local default_profile
    
    # Method 1: Look for Install section with Default= entry (modern Firefox)
    default_profile=$(grep "^Default=" "$profiles_ini" | head -1 | cut -d'=' -f2)
    
    # Method 2: Look for Profile0 section (older Firefox)
    if [[ -z "$default_profile" ]]; then
        default_profile=$(grep -A 3 "\[Profile0\]" "$profiles_ini" | grep "^Path=" | cut -d'=' -f2)
    fi
    
    # Method 3: Find any profile with default-release in name
    if [[ -z "$default_profile" ]]; then
        default_profile=$(grep "^Path=" "$profiles_ini" | grep "default-release" | head -1 | cut -d'=' -f2)
    fi
    
    # Method 4: Just take the first profile path found
    if [[ -z "$default_profile" ]]; then
        default_profile=$(grep "^Path=" "$profiles_ini" | head -1 | cut -d'=' -f2)
    fi
    
    if [[ -z "$default_profile" ]]; then
        log_error "Could not find Firefox default profile in profiles.ini"
        return 1
    fi
    
    # Handle relative paths (modern Firefox uses Profiles/ subdirectory)
    local profile_path
    if [[ "$default_profile" == Profiles/* ]] || [[ "$default_profile" == */* ]]; then
        profile_path="$firefox_profiles_dir/$default_profile"
    else
        profile_path="$firefox_profiles_dir/$default_profile"
    fi
    
    if [[ ! -d "$profile_path" ]]; then
        log_error "Profile directory not found: $profile_path"
        return 1
    fi
    
    echo "$profile_path"
}

# Check if URL matches exclusion pattern
url_matches_pattern() {
    local url="$1"
    local pattern="$2"
    
    # Use case statement for pattern matching (supports shell wildcards)
    case "$url" in
        $pattern) return 0 ;;
        *) return 1 ;;
    esac
}

# Check if URL should be excluded
should_exclude_url() {
    local url="$1"
    
    # Skip common non-content file types
    local non_content_extensions=("css" "js" "png" "jpg" "jpeg" "gif" "svg" "ico" "woff" "woff2" "ttf" "pdf" "zip" "tar" "gz")
    
    for ext in "${non_content_extensions[@]}"; do
        case "$url" in
            *.$ext|*.$ext\?*) 
                log_verbose "Skipping non-content file: $url"
                return 0 
                ;;
        esac
    done
    
    # Check user-defined exclusion patterns
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if url_matches_pattern "$url" "$pattern"; then
                log_verbose "Excluding URL (matches pattern '$pattern'): $url"
                return 0
            fi
        done
    fi
    
    return 1
}

# Calculate timestamp for N days ago
get_timestamp_days_ago() {
    local days_ago="$1"
    local seconds_ago=$((days_ago * 24 * 60 * 60))
    local timestamp_seconds=$(($(date +%s) - seconds_ago))
    # Firefox stores timestamps in microseconds
    local timestamp_microseconds=$((timestamp_seconds * 1000000))
    echo "$timestamp_microseconds"
}

# Format timestamp for display
format_timestamp() {
    local microseconds="$1"
    local seconds=$((microseconds / 1000000))
    date -r "$seconds" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown"
}

# Extract URLs from Firefox database
extract_firefox_urls() {
    log_info "Detecting Firefox profile..."
    
    local profile_path
    profile_path=$(find_firefox_profile)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    log_verbose "Firefox profile found: $profile_path"
    
    local places_db="$profile_path/places.sqlite"
    if [[ ! -f "$places_db" ]]; then
        log_error "Firefox history database not found: $places_db"
        exit 1
    fi
    
    log_info "Extracting URLs from Firefox history (last $DAYS days)..."
    
    local timestamp_limit
    timestamp_limit=$(get_timestamp_days_ago "$DAYS")
    
    log_verbose "Querying history since timestamp: $timestamp_limit"
    
    # SQL query using browserexport approach with immutable=1 for locked databases
    local sql_query="SELECT p.url, COALESCE(p.title, p.url) as title, (CASE WHEN (h.visit_date > 300000000 * 1000000) THEN h.visit_date ELSE h.visit_date * 1000 END) as visit_date FROM moz_historyvisits as h, moz_places as p WHERE h.place_id = p.id AND h.visit_date > $timestamp_limit AND p.url NOT LIKE 'about:%' AND p.url NOT LIKE 'moz-extension:%' AND p.url NOT LIKE 'chrome:%' AND p.url NOT LIKE 'resource:%' AND p.url NOT LIKE 'file://%' AND p.url LIKE 'http%' ORDER BY h.visit_date DESC;"
    
    log_verbose "Executing SQL query on database: $places_db"
    
    # Create temporary file for raw results
    local temp_file
    temp_file=$(mktemp)
    
    # Execute query with immutable=1 to handle locked databases
    if ! sqlite3 "file:$places_db?immutable=1" "$sql_query" > "$temp_file"; then
        log_error "Failed to query Firefox history database"
        rm -f "$temp_file"
        exit 1
    fi
    
    local total_urls
    total_urls=$(wc -l < "$temp_file")
    log_info "Found $total_urls URLs in Firefox history"
    
    if [[ "$total_urls" -eq 0 ]]; then
        log_warn "No URLs found in the last $DAYS days"
        rm -f "$temp_file"
        exit 0
    fi
    
    # Process and filter URLs
    local kept_count=0
    local excluded_count=0
    
    while IFS='|' read -r url title timestamp; do
        if should_exclude_url "$url"; then
            ((excluded_count++))
            continue
        fi
        
        ((kept_count++))
        
        # Output in TSV format: URL<tab>TITLE<tab>TIMESTAMP
        printf "%s\t%s\t%s\n" "$url" "$title" "$timestamp"
        
    done < "$temp_file"
    
    log_info "URL filtering completed: $kept_count kept, $excluded_count excluded" >&2
    
    rm -f "$temp_file"
}

# Main function
main() {
    parse_arguments "$@"
    
    log_info "Firefox URL Extractor starting..."
    log_verbose "Configuration: days=$DAYS, exclude_patterns=${#EXCLUDE_PATTERNS[@]}, output=$OUTPUT_FILE"
    
    if [[ -n "$OUTPUT_FILE" ]]; then
        extract_firefox_urls > "$OUTPUT_FILE"
        log_success "URLs extracted to: $OUTPUT_FILE"
    else
        extract_firefox_urls
    fi
}

# Execute main function
main "$@"