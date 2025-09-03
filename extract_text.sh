#!/bin/bash

# HTML Text Extractor
# Extracts clean text content from HTML files

set -uo pipefail

# Default values
INPUT_DIR=""
OUTPUT_DIR=""
MAX_LENGTH=10000
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
Usage: $0 -i INPUT_DIR -o OUTPUT_DIR [options]

HTML Text Extractor - Extract clean text content from HTML files

Required:
  -i, --input DIR           Input directory with HTML files
  -o, --output DIR          Output directory for text files

Options:
  -l, --length CHARS        Maximum text length (default: 10000)
  -f, --force               Overwrite existing text files
  -v, --verbose             Enable verbose output
  -h, --help                Show this help message

Examples:
  $0 -i content/ -o text/
  $0 -i content/ -o text/ -l 5000 --force
  $0 -i scraped_html/ -o clean_text/ --verbose

Input format: {hash}.html files
Output format: {hash}.txt files with clean text

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -l|--length)
                MAX_LENGTH="$2"
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
    if [[ -z "$INPUT_DIR" ]]; then
        log_error "Input directory is required. Use -i or --input option."
        usage
        exit 1
    fi

    if [[ -z "$OUTPUT_DIR" ]]; then
        log_error "Output directory is required. Use -o or --output option."
        usage
        exit 1
    fi

    # Validate directories
    if [[ ! -d "$INPUT_DIR" ]]; then
        log_error "Input directory not found: $INPUT_DIR"
        exit 1
    fi

    # Validate numeric arguments
    if ! [[ "$MAX_LENGTH" =~ ^[0-9]+$ ]] || [[ "$MAX_LENGTH" -lt 100 ]]; then
        log_error "Max length must be at least 100 characters."
        exit 1
    fi
}

# Clean HTML and extract text  
extract_text_from_html() {
    local html_file="$1"
    local text_content
    
    log_verbose "Processing: $(basename "$html_file")"
    
    # Read HTML content
    if [[ ! -f "$html_file" ]] || [[ ! -s "$html_file" ]]; then
        log_verbose "Skipping empty or missing file: $html_file"
        return 1
    fi
    
    # Use Python for better HTML cleaning if available, otherwise fall back to sed
    if command -v python3 >/dev/null 2>&1; then
        text_content=$(python3 -c "
import html
import re
import sys

try:
    with open('$html_file', 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Remove script and style blocks
    content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL | re.IGNORECASE)
    content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.DOTALL | re.IGNORECASE)
    
    # Remove HTML comments
    content = re.sub(r'<!--.*?-->', '', content, flags=re.DOTALL)
    
    # Remove all HTML tags
    content = re.sub(r'<[^>]+>', '', content)
    
    # Decode HTML entities
    content = html.unescape(content)
    
    # Clean up whitespace
    content = re.sub(r'\s+', ' ', content).strip()
    
    print(content)
    
except Exception as e:
    sys.exit(1)
")
    else
        # Fallback to sed-based approach
        text_content=$(cat "$html_file" | \
            tr '\n\r' ' ' | \
            sed 's/<script[^>]*>.*<\/script>//gI' | \
            sed 's/<style[^>]*>.*<\/style>//gI' | \
            sed 's/<!--.*-->//g' | \
            sed 's/<[^>]*>//g' | \
            sed 's/&[a-zA-Z][a-zA-Z0-9]*;//g' | \
            sed 's/[[:space:]]\{1,\}/ /g' | \
            sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    fi
    
    # Check if we got meaningful content
    if [[ -z "$text_content" ]] || [[ ${#text_content} -lt 50 ]]; then
        log_verbose "No meaningful text content found in: $(basename "$html_file")"
        return 1
    fi
    
    # Truncate if too long
    if [[ ${#text_content} -gt $MAX_LENGTH ]]; then
        text_content="${text_content:0:$MAX_LENGTH}"
        log_verbose "Text truncated to $MAX_LENGTH characters for: $(basename "$html_file")"
    fi
    
    echo "$text_content"
}

# Progress tracking
update_progress() {
    local current="$1"
    local total="$2"
    local percent=$((current * 100 / total))
    printf "\r${BLUE}[INFO]${NC} Progress: %d/%d (%d%%)" "$current" "$total" "$percent" >&2
    [[ "$current" -eq "$total" ]] && echo >&2
}

# Process HTML files and extract text
process_html_files() {
    # Count HTML files in input directory
    local total_files
    total_files=$(find "$INPUT_DIR" -name "*.html" -type f | wc -l)
    
    if [[ $total_files -eq 0 ]]; then
        log_warn "No HTML files found in: $INPUT_DIR"
        exit 0
    fi
    
    log_info "Processing $total_files HTML files from: $INPUT_DIR"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Max text length: $MAX_LENGTH characters"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local current=0
    local success_count=0
    local cache_hits=0
    
    # Process each HTML file
    find "$INPUT_DIR" -name "*.html" -type f | while read -r html_file; do
        ((current++))
        
        # Generate corresponding text filename
        local basename_file
        basename_file=$(basename "$html_file" .html)
        local text_file="$OUTPUT_DIR/${basename_file}.txt"
        
        # Check if text file already exists (unless force flag is set)
        if [[ -f "$text_file" ]] && [[ "$FORCE" != true ]]; then
            log_verbose "Using existing text file for: $(basename "$html_file")"
            ((cache_hits++))
            ((success_count++))
            update_progress "$current" "$total_files"
            continue
        fi
        
        # Extract text from HTML
        local text_content
        if text_content=$(extract_text_from_html "$html_file"); then
            # Save to text file
            echo "$text_content" > "$text_file"
            ((success_count++))
            log_verbose "Successfully extracted text from: $(basename "$html_file")"
        else
            log_verbose "Failed to extract text from: $(basename "$html_file")"
        fi
        
        update_progress "$current" "$total_files"
    done
    
    # Count final results
    local final_text_count
    final_text_count=$(find "$OUTPUT_DIR" -name "*.txt" -type f 2>/dev/null | wc -l)
    
    log_success "Text extraction completed: $final_text_count/$total_files files successfully processed"
    
    # Report final statistics
    local failed_count=$((total_files - final_text_count))
    if [[ "$failed_count" -gt 0 ]]; then
        log_warn "$failed_count files failed to process or had no meaningful content"
    fi
    
    log_info "Text directory contains $final_text_count text files"
}

# Main function
main() {
    parse_arguments "$@"
    
    log_info "HTML Text Extractor starting..."
    log_verbose "Configuration: max_length=$MAX_LENGTH, force=$FORCE"
    
    process_html_files
    
    log_success "Text extraction completed successfully!"
}

# Execute main function
main "$@"