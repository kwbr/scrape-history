#!/bin/bash

# Keyword Finder
# Searches for keywords in text files and generates structured results

set -uo pipefail

# Default values
TEXT_DIR=""
URLS_FILE=""
KEYWORDS=""
OUTPUT_FILE=""
MATCH_ANY=false
CONTEXT_CHARS=100
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
Usage: $0 -t TEXT_DIR -u URLS_FILE -k KEYWORDS [options]

Keyword Finder - Search for keywords in text files

Required:
  -t, --text DIR            Directory with text files
  -u, --urls FILE           TSV file with URL metadata
  -k, --keywords LIST       Comma-separated keywords to search for

Options:
  -o, --output FILE         Output JSON file (default: stdout)
  --match-any               Use OR logic for keywords (default: AND)
  -c, --context CHARS       Context characters around matches (default: 100)
  -v, --verbose             Enable verbose output
  -h, --help                Show this help message

Examples:
  $0 -t text/ -u urls.tsv -k "python,tutorial" -o matches.json
  $0 -t text/ -u urls.tsv -k "github" --match-any
  $0 -t text/ -u urls.tsv -k "docker,kubernetes" -c 200 --verbose

Input: Text files with hash names, TSV file with URL metadata
Output: JSON with matches, context, and metadata

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--text)
                TEXT_DIR="$2"
                shift 2
                ;;
            -u|--urls)
                URLS_FILE="$2"
                shift 2
                ;;
            -k|--keywords)
                KEYWORDS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --match-any)
                MATCH_ANY=true
                shift
                ;;
            -c|--context)
                CONTEXT_CHARS="$2"
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

    # Validate required arguments
    if [[ -z "$TEXT_DIR" ]]; then
        log_error "Text directory is required. Use -t or --text option."
        usage
        exit 1
    fi

    if [[ -z "$URLS_FILE" ]]; then
        log_error "URLs file is required. Use -u or --urls option."
        usage
        exit 1
    fi

    if [[ -z "$KEYWORDS" ]]; then
        log_error "Keywords are required. Use -k or --keywords option."
        usage
        exit 1
    fi

    # Validate files and directories
    if [[ ! -d "$TEXT_DIR" ]]; then
        log_error "Text directory not found: $TEXT_DIR"
        exit 1
    fi

    if [[ ! -f "$URLS_FILE" ]]; then
        log_error "URLs file not found: $URLS_FILE"
        exit 1
    fi

    # Validate numeric arguments
    if ! [[ "$CONTEXT_CHARS" =~ ^[0-9]+$ ]] || [[ "$CONTEXT_CHARS" -lt 10 ]]; then
        log_error "Context chars must be at least 10."
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("jq")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install jq: brew install jq (macOS) or apt-get install jq (Ubuntu)"
        exit 1
    fi
}

# Generate hash from URL for filename lookup
get_url_hash() {
    local url="$1"
    echo -n "$url" | shasum -a 256 | cut -d' ' -f1
}

# Check if content contains keywords with specified logic
content_matches_keywords() {
    local content="$1"
    local keywords_array=()
    
    # Convert comma-separated keywords to array
    IFS=',' read -ra keywords_array <<< "$KEYWORDS"
    
    local matches=0
    local total_keywords=${#keywords_array[@]}
    
    for keyword in "${keywords_array[@]}"; do
        # Trim whitespace
        keyword=$(echo "$keyword" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        
        if echo "$content" | grep -qi "$keyword"; then
            ((matches++))
        fi
    done
    
    # Return true if match logic is satisfied
    if [[ "$MATCH_ANY" == true ]]; then
        [[ $matches -gt 0 ]]
    else
        [[ $matches -eq $total_keywords ]]
    fi
}

# Extract keyword context snippets from content
extract_keyword_context() {
    local content="$1"
    local keywords_array=()
    local contexts=()
    
    # Convert comma-separated keywords to array
    IFS=',' read -ra keywords_array <<< "$KEYWORDS"
    
    for keyword in "${keywords_array[@]}"; do
        # Trim whitespace
        keyword=$(echo "$keyword" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        
        # Find context around keyword (case-insensitive) 
        local context
        context=$(echo "$content" | grep -io ".\{0,$CONTEXT_CHARS\}$keyword.\{0,$CONTEXT_CHARS\}" | head -1)
        
        if [[ -n "$context" ]]; then
            # Clean up the context
            context=$(echo "$context" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '\n\r\t' ' ')
            contexts+=("$context")
        fi
    done
    
    # Use jq to create proper JSON array
    if [[ ${#contexts[@]} -gt 0 ]]; then
        printf '%s\n' "${contexts[@]}" | jq -R -s 'split("\n") | .[:-1]'
    else
        echo "[]"
    fi
}

# Count keyword matches in content
count_keyword_matches() {
    local content="$1"
    local keywords_array=()
    local total_matches=0
    
    # Convert comma-separated keywords to array
    IFS=',' read -ra keywords_array <<< "$KEYWORDS"
    
    for keyword in "${keywords_array[@]}"; do
        # Trim whitespace
        keyword=$(echo "$keyword" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        
        local count
        count=$(echo "$content" | grep -oi "$keyword" | wc -l)
        ((total_matches += count))
    done
    
    echo "$total_matches"
}

# Progress tracking
update_progress() {
    local current="$1"
    local total="$2"
    local percent=$((current * 100 / total))
    printf "\r${BLUE}[INFO]${NC} Progress: %d/%d (%d%%)" "$current" "$total" "$percent" >&2
    [[ "$current" -eq "$total" ]] && echo >&2
}

# Escape JSON strings
json_escape() {
    local input="$1"
    # Basic JSON escaping for the most common problematic characters
    echo "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g; s/\r/\\r/g'
}

# Format timestamp for display
format_timestamp() {
    local microseconds="$1"
    local seconds=$((microseconds / 1000000))
    date -r "$seconds" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown"
}

# Process text files and find keyword matches
find_keyword_matches() {
    log_info "Searching for keywords in text files..."
    log_info "Keywords: $KEYWORDS"
    log_info "Match logic: $([ "$MATCH_ANY" = true ] && echo "OR (any keyword)" || echo "AND (all keywords)")"
    
    # Count text files
    local total_files
    total_files=$(find "$TEXT_DIR" -name "*.txt" -type f | wc -l)
    
    if [[ $total_files -eq 0 ]]; then
        log_warn "No text files found in: $TEXT_DIR"
        echo "[]"
        return 0
    fi
    
    log_info "Processing $total_files text files"
    
    local current=0
    local matches=()
    
    # Create temp file for URL metadata lookup
    local metadata_file
    metadata_file=$(mktemp)
    
    while IFS=$'\t' read -r url title timestamp || [[ -n "$url" ]]; do
        [[ -z "$url" ]] && continue
        local hash
        hash=$(get_url_hash "$url")
        echo "$hash|$url|$title|$timestamp" >> "$metadata_file"
    done < "$URLS_FILE"
    
    # Process each text file
    find "$TEXT_DIR" -name "*.txt" -type f | while read -r text_file; do
        ((current++))
        
        local basename_file
        basename_file=$(basename "$text_file" .txt)
        
        log_verbose "Processing: $basename_file"
        
        # Read text content
        local content
        if [[ ! -f "$text_file" ]] || [[ ! -s "$text_file" ]]; then
            log_verbose "Skipping empty file: $text_file"
            update_progress "$current" "$total_files"
            continue
        fi
        
        content=$(cat "$text_file")
        
        # Check if content matches keywords
        if content_matches_keywords "$content"; then
            log_verbose "Match found in: $basename_file"
            
            # Get URL metadata
            local url_info
            url_info=$(grep "^$basename_file|" "$metadata_file" | head -1)
            if [[ -z "$url_info" ]]; then
                log_verbose "No URL metadata found for: $basename_file"
                update_progress "$current" "$total_files"
                continue
            fi
            
            IFS='|' read -r hash url title timestamp <<< "$url_info"
            
            # Extract context and count matches
            local contexts
            contexts=$(extract_keyword_context "$content")
            
            local match_count
            match_count=$(count_keyword_matches "$content")
            
            local formatted_date
            formatted_date=$(format_timestamp "$timestamp")
            
            # Use jq to create properly formatted JSON
            jq -n \
                --arg url "$url" \
                --arg title "$title" \
                --arg timestamp "$timestamp" \
                --arg date "$formatted_date" \
                --argjson match_count "$match_count" \
                --argjson contexts "$contexts" \
                '{
                    url: $url,
                    title: $title,
                    timestamp: $timestamp,
                    date: $date,
                    match_count: $match_count,
                    contexts: $contexts
                }'
        fi
        
        update_progress "$current" "$total_files"
    done
    
    # Clean up temp file
    rm -f "$metadata_file"
}

# Main function
main() {
    parse_arguments "$@"
    check_dependencies
    
    log_info "Keyword Finder starting..."
    log_verbose "Configuration: match_any=$MATCH_ANY, context_chars=$CONTEXT_CHARS"
    
    # Generate matches and create JSON array
    local matches_output
    matches_output=$(find_keyword_matches)
    
    # Convert individual JSON objects to array using jq
    local json_array
    if [[ -n "$matches_output" ]] && [[ "$matches_output" != "" ]]; then
        json_array=$(echo "$matches_output" | jq -s '.')
    else
        json_array="[]"
    fi
    
    # Debug: show raw JSON
    log_verbose "Raw JSON array: $json_array"
    
    # Count matches
    local match_count
    if echo "$json_array" | jq . > /dev/null 2>&1; then
        match_count=$(echo "$json_array" | jq length)
        log_info "Keyword search completed: $match_count matches found"
        
        # Output results
        if [[ -n "$OUTPUT_FILE" ]]; then
            echo "$json_array" | jq . > "$OUTPUT_FILE"
            log_success "Results saved to: $OUTPUT_FILE"
        else
            echo "$json_array" | jq .
        fi
    else
        log_error "Invalid JSON generated: $json_array"
        log_info "Raw matches output was: '$matches_output'"
        exit 1
    fi
    
    log_success "Keyword search completed successfully!"
}

# Execute main function
main "$@"