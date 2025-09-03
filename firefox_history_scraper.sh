#!/bin/bash

# Firefox History Keyword Scraper (Modular Version)
# Orchestrates the modular pipeline to scrape Firefox history for keywords

set -uo pipefail

# Default values
KEYWORDS=""
DAYS=7
EXCLUDE_PATTERNS=()
OUTPUT_FILE="history_results.html"
MATCH_ANY=false
VERBOSE=false
CLEANUP=true
WORK_DIR=""

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
Usage: $0 -k "keyword1,keyword2" [options]

Firefox History Keyword Scraper - Search your browsing history for specific keywords

Required:
  -k, --keywords KEYWORDS    Comma-separated keywords to search for

Options:
  -d, --days DAYS           Number of days back to search (default: 7)
  -e, --exclude PATTERN     URL pattern to exclude (can be used multiple times)
  -o, --output FILE         Output HTML file (default: history_results.html)
  --match-any               Use OR logic for keywords (default: AND logic)
  --no-cleanup              Keep intermediate files after completion
  -v, --verbose             Enable verbose output
  -h, --help                Show this help message

Examples:
  $0 -k "python,machine learning" -d 14
  $0 -k "github" -e "*.google.com" -e "*/admin/*" -o results.html
  $0 -k "docker,kubernetes" --match-any -d 30

Pipeline:
  1. Extract URLs from Firefox history (extract_firefox_urls.sh)
  2. Scrape web content from URLs (scrape_urls.sh)
  3. Extract clean text from HTML (extract_text.sh)
  4. Find keyword matches (find_keywords.sh)
  5. Generate HTML report (generate_report.sh)

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--keywords)
                KEYWORDS="$2"
                shift 2
                ;;
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
            --match-any)
                MATCH_ANY=true
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
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
    if [[ -z "$KEYWORDS" ]]; then
        log_error "Keywords are required. Use -k or --keywords option."
        usage
        exit 1
    fi

    # Validate numeric arguments
    if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
        log_error "Days must be a positive integer."
        exit 1
    fi
}

# Check required scripts
check_dependencies() {
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"
    
    local required_scripts=(
        "extract_firefox_urls.sh"
        "scrape_urls.sh" 
        "extract_text.sh"
        "find_keywords.sh"
        "generate_report.sh"
    )
    
    local missing=()
    
    for script in "${required_scripts[@]}"; do
        local script_path="$script_dir/$script"
        if [[ ! -f "$script_path" ]] || [[ ! -x "$script_path" ]]; then
            missing+=("$script")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required scripts: ${missing[*]}"
        log_error "Please ensure all modular scripts are in the same directory and executable"
        exit 1
    fi
    
    log_verbose "All required scripts found and executable"
}

# Create working directory
setup_work_environment() {
    WORK_DIR=$(mktemp -d -t firefox_history_scraper.XXXXXX)
    log_verbose "Working directory: $WORK_DIR"
    
    # Ensure cleanup on exit
    if [[ "$CLEANUP" == true ]]; then
        trap cleanup_work_environment EXIT
    fi
}

# Cleanup working directory
cleanup_work_environment() {
    if [[ -n "$WORK_DIR" ]] && [[ -d "$WORK_DIR" ]]; then
        log_verbose "Cleaning up working directory: $WORK_DIR"
        rm -rf "$WORK_DIR"
    fi
}

# Build exclude arguments for extract_firefox_urls.sh
build_exclude_args() {
    local exclude_args=()
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            exclude_args+=("-e" "$pattern")
        done
    fi
    if [[ ${#exclude_args[@]} -gt 0 ]]; then
        echo "${exclude_args[@]}"
    else
        echo ""
    fi
}

# Execute pipeline step with error handling
execute_step() {
    local step_name="$1"
    local step_command="$2"
    
    log_info "Step: $step_name"
    log_verbose "Command: $step_command"
    
    if eval "$step_command"; then
        log_success "Step completed: $step_name"
    else
        log_error "Step failed: $step_name"
        log_error "Command was: $step_command"
        exit 1
    fi
}

# Main pipeline execution
run_pipeline() {
    local script_dir
    script_dir="$(dirname "$(realpath "$0")")"
    
    # Pipeline file paths
    local urls_file="$WORK_DIR/urls.tsv"
    local content_dir="$WORK_DIR/content"
    local text_dir="$WORK_DIR/text"
    local results_file="$WORK_DIR/results.json"
    
    # Step 1: Extract Firefox URLs
    log_info "Step: Extract URLs from Firefox history"
    
    local extract_cmd=("$script_dir/extract_firefox_urls.sh" "-d" "$DAYS")
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            extract_cmd+=("-e" "$pattern")
        done
    fi
    extract_cmd+=("-o" "$urls_file")
    [[ "$VERBOSE" == true ]] && extract_cmd+=("-v")
    
    log_verbose "Command: ${extract_cmd[*]}"
    
    if "${extract_cmd[@]}"; then
        log_success "Step completed: Extract URLs from Firefox history"
    else
        log_error "Step failed: Extract URLs from Firefox history"
        exit 1
    fi
    
    # Check if we got any URLs
    if [[ ! -f "$urls_file" ]] || [[ ! -s "$urls_file" ]]; then
        log_warn "No URLs found in Firefox history for the specified criteria"
        log_info "Try increasing --days or removing exclusion patterns"
        exit 0
    fi
    
    local url_count
    url_count=$(wc -l < "$urls_file")
    log_info "Found $url_count URLs to process"
    
    # Step 2: Scrape web content  
    local scrape_cmd=("$script_dir/scrape_urls.sh" "-i" "$urls_file" "-o" "$content_dir")
    [[ "$VERBOSE" == true ]] && scrape_cmd+=("-v")
    
    log_info "Step: Scrape web content from URLs"
    log_verbose "Command: ${scrape_cmd[*]}"
    
    "${scrape_cmd[@]}"
    local scrape_exit_code=$?
    
    # Always check for scraped content regardless of exit code
    local scraped_count
    scraped_count=$(find "$content_dir" -name "*.html" 2>/dev/null | wc -l)
    
    if [[ "$scraped_count" -gt 0 ]]; then
        if [[ "$scrape_exit_code" -ne 0 ]]; then
            log_warn "Some URLs failed to scrape, but got $scraped_count files. Continuing..."
        else
            log_success "Step completed: Scrape web content from URLs"
        fi
    else
        log_error "Step failed: No URLs were successfully scraped"
        exit 1
    fi
    
    # Step 3: Extract text from HTML
    local extract_text_cmd=("$script_dir/extract_text.sh" "-i" "$content_dir" "-o" "$text_dir")
    [[ "$VERBOSE" == true ]] && extract_text_cmd+=("-v")
    
    log_info "Step: Extract clean text from HTML files"
    log_verbose "Command: ${extract_text_cmd[*]}"
    
    if "${extract_text_cmd[@]}"; then
        log_success "Step completed: Extract clean text from HTML files"
    else
        log_error "Step failed: Extract clean text from HTML files"
        exit 1
    fi
    
    # Step 4: Find keyword matches
    local find_cmd=("$script_dir/find_keywords.sh" "-t" "$text_dir" "-u" "$urls_file" "-k" "$KEYWORDS")
    [[ "$MATCH_ANY" == true ]] && find_cmd+=("--match-any")
    find_cmd+=("-o" "$results_file")
    [[ "$VERBOSE" == true ]] && find_cmd+=("-v")
    
    log_info "Step: Search for keyword matches"
    log_verbose "Command: ${find_cmd[*]}"
    
    if "${find_cmd[@]}"; then
        log_success "Step completed: Search for keyword matches"
    else
        log_error "Step failed: Search for keyword matches"
        exit 1
    fi
    
    # Step 5: Generate HTML report
    local report_title="Firefox History Search: $KEYWORDS"
    local report_cmd=("$script_dir/generate_report.sh" "-i" "$results_file" "-o" "$OUTPUT_FILE" "-t" "$report_title")
    [[ "$VERBOSE" == true ]] && report_cmd+=("-v")
    
    log_info "Step: Generate HTML report"
    log_verbose "Command: ${report_cmd[*]}"
    
    if "${report_cmd[@]}"; then
        log_success "Step completed: Generate HTML report"
    else
        log_error "Step failed: Generate HTML report"
        exit 1
    fi
    
    # Report final results
    local match_count=0
    if [[ -f "$results_file" ]]; then
        match_count=$(jq length "$results_file" 2>/dev/null || echo "0")
    fi
    
    log_success "Pipeline completed successfully!"
    log_info "Keywords searched: $KEYWORDS"
    log_info "URLs processed: $url_count"
    log_info "Matches found: $match_count"
    log_info "Report generated: $OUTPUT_FILE"
    log_info "Open in browser: file://$(realpath "$OUTPUT_FILE")"
    
    # Show intermediate files location if no cleanup
    if [[ "$CLEANUP" == false ]]; then
        log_info "Intermediate files preserved in: $WORK_DIR"
        log_info "  - URLs: $urls_file"
        log_info "  - Content: $content_dir"
        log_info "  - Text: $text_dir" 
        log_info "  - Results: $results_file"
    fi
}

# Main function
main() {
    parse_arguments "$@"
    check_dependencies
    setup_work_environment
    
    log_info "Firefox History Keyword Scraper starting..."
    log_info "Target keywords: $KEYWORDS"
    log_info "Search period: last $DAYS days"
    log_info "Match logic: $([ "$MATCH_ANY" = true ] && echo "OR (any keyword)" || echo "AND (all keywords)")"
    log_info "Output file: $OUTPUT_FILE"
    
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        log_info "Exclusion patterns: ${EXCLUDE_PATTERNS[*]}"
    fi
    
    run_pipeline
}

# Execute main function
main "$@"