#!/bin/bash

# HTML Report Generator
# Creates an interactive HTML report from keyword search results

set -uo pipefail

# Default values
INPUT_FILE=""
OUTPUT_FILE=""
TITLE="Firefox History Keyword Search Results"
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
Usage: $0 -i INPUT_FILE -o OUTPUT_FILE [options]

HTML Report Generator - Create interactive HTML report from search results

Required:
  -i, --input FILE          JSON file with keyword search results
  -o, --output FILE         Output HTML file

Options:
  -t, --title TITLE         Report title (default: "Firefox History Keyword Search Results")
  -v, --verbose             Enable verbose output
  -h, --help                Show this help message

Examples:
  $0 -i search_results.json -o report.html
  $0 -i results.json -o report.html -t "My Search Results"
  $0 -i matches.json -o index.html --verbose

Input: JSON array with search matches
Output: Interactive HTML report with clickable links

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
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -t|--title)
                TITLE="$2"
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
    if [[ -z "$INPUT_FILE" ]]; then
        log_error "Input file is required. Use -i or --input option."
        usage
        exit 1
    fi

    if [[ -z "$OUTPUT_FILE" ]]; then
        log_error "Output file is required. Use -o or --output option."
        usage
        exit 1
    fi

    # Validate input file
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "Input file not found: $INPUT_FILE"
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

# Generate HTML report
generate_html_report() {
    local matches_json
    matches_json=$(cat "$INPUT_FILE")
    
    log_verbose "Input JSON: $matches_json"
    
    # Validate JSON
    if ! echo "$matches_json" | jq . > /dev/null 2>&1; then
        log_error "Invalid JSON in input file: $INPUT_FILE"
        exit 1
    fi
    
    local match_count
    match_count=$(echo "$matches_json" | jq length)
    
    log_info "Generating HTML report for $match_count matches..."
    
    # Generate HTML content
    cat > "$OUTPUT_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>REPORT_TITLE</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: white;
            border-radius: 8px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            color: #2c3e50;
            margin-bottom: 10px;
        }
        
        .stats {
            display: flex;
            gap: 20px;
            margin-top: 15px;
        }
        
        .stat {
            background: #3498db;
            color: white;
            padding: 10px 20px;
            border-radius: 6px;
            font-weight: 600;
        }
        
        .results {
            display: grid;
            gap: 20px;
        }
        
        .result-item {
            background: white;
            border-radius: 8px;
            padding: 25px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid #3498db;
        }
        
        .result-item:hover {
            box-shadow: 0 4px 8px rgba(0,0,0,0.15);
            transform: translateY(-2px);
            transition: all 0.3s ease;
        }
        
        .result-title {
            font-size: 1.2em;
            font-weight: 600;
            margin-bottom: 10px;
        }
        
        .result-title a {
            color: #2c3e50;
            text-decoration: none;
        }
        
        .result-title a:hover {
            color: #3498db;
            text-decoration: underline;
        }
        
        .result-url {
            color: #7f8c8d;
            font-size: 0.9em;
            margin-bottom: 15px;
            word-break: break-all;
        }
        
        .result-meta {
            display: flex;
            gap: 15px;
            margin-bottom: 15px;
            font-size: 0.9em;
        }
        
        .meta-item {
            background: #ecf0f1;
            padding: 4px 8px;
            border-radius: 4px;
            color: #2c3e50;
        }
        
        .contexts {
            margin-top: 15px;
        }
        
        .contexts h4 {
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .context-item {
            background: #f8f9fa;
            padding: 12px;
            margin-bottom: 8px;
            border-radius: 4px;
            font-family: monospace;
            font-size: 0.85em;
            line-height: 1.4;
            border-left: 3px solid #e74c3c;
        }
        
        .no-results {
            text-align: center;
            padding: 60px 20px;
            color: #7f8c8d;
        }
        
        .no-results h2 {
            margin-bottom: 10px;
            color: #95a5a6;
        }
        
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #7f8c8d;
            font-size: 0.9em;
        }
        
        @media (max-width: 768px) {
            .stats {
                flex-direction: column;
            }
            
            .result-meta {
                flex-direction: column;
                gap: 8px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>REPORT_TITLE</h1>
            <p>Firefox history keyword search results</p>
            <div class="stats">
                <div class="stat">MATCH_COUNT matches found</div>
                <div class="stat">Generated on GENERATION_DATE</div>
            </div>
        </div>
        
        <div class="results" id="results">
            RESULTS_PLACEHOLDER
        </div>
        
        <div class="footer">
            <p>Generated by Firefox History Scraper</p>
        </div>
    </div>
</body>
</html>
EOF

    # Replace placeholders
    local generation_date
    generation_date=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Escape title for sed
    local escaped_title
    escaped_title=$(echo "$TITLE" | sed 's/[\/&]/\\&/g')
    
    # Replace basic placeholders
    sed -i.tmp "s/REPORT_TITLE/$escaped_title/g" "$OUTPUT_FILE"
    sed -i.tmp "s/MATCH_COUNT/$match_count/g" "$OUTPUT_FILE"
    sed -i.tmp "s/GENERATION_DATE/$generation_date/g" "$OUTPUT_FILE"
    
    # Generate results HTML
    local results_html=""
    
    if [[ $match_count -eq 0 ]]; then
        results_html='<div class="no-results"><h2>No matches found</h2><p>Try different keywords or expand your search criteria.</p></div>'
    else
        # Process each match using jq
        while IFS= read -r match; do
            local url title date timestamp match_count_item contexts_json
            
            url=$(echo "$match" | jq -r '.url')
            title=$(echo "$match" | jq -r '.title')
            date=$(echo "$match" | jq -r '.date')
            timestamp=$(echo "$match" | jq -r '.timestamp')
            match_count_item=$(echo "$match" | jq -r '.match_count')
            contexts_json=$(echo "$match" | jq -r '.contexts[]?' 2>/dev/null || echo "")
            
            log_verbose "Processing match: $title"
            
            # Build contexts HTML
            local contexts_html=""
            if [[ -n "$contexts_json" ]]; then
                contexts_html='<div class="contexts"><h4>Context Snippets</h4>'
                echo "$match" | jq -r '.contexts[]?' | while read -r context; do
                    [[ -n "$context" ]] && contexts_html+="<div class=\"context-item\">$(echo "$context" | sed 's/</\&lt;/g; s/>/\&gt;/g')</div>"
                done
                contexts_html+='</div>'
            fi
            
            # Build result item HTML
            results_html+="<div class=\"result-item\">"
            results_html+="<div class=\"result-title\"><a href=\"$(echo "$url" | sed 's/</\&lt;/g; s/>/\&gt;/g')\" target=\"_blank\">$(echo "$title" | sed 's/</\&lt;/g; s/>/\&gt;/g')</a></div>"
            results_html+="<div class=\"result-url\">$(echo "$url" | sed 's/</\&lt;/g; s/>/\&gt;/g')</div>"
            results_html+="<div class=\"result-meta\">"
            results_html+="<span class=\"meta-item\">📅 $date</span>"
            results_html+="<span class=\"meta-item\">🔍 $match_count_item matches</span>"
            results_html+="</div>"
            results_html+="$contexts_html"
            results_html+="</div>"
            
        done <<< "$(echo "$matches_json" | jq -c '.[]')"
    fi
    
    # Replace results placeholder (need to escape for sed)
    local temp_file
    temp_file=$(mktemp)
    echo "$results_html" > "$temp_file"
    
    # Use a more reliable method to replace the placeholder
    python3 -c "
import sys
with open('$OUTPUT_FILE', 'r') as f:
    content = f.read()
with open('$temp_file', 'r') as f:
    results = f.read()
content = content.replace('RESULTS_PLACEHOLDER', results)
with open('$OUTPUT_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null || {
    # Fallback if python3 is not available
    log_verbose "Using sed fallback for HTML generation"
    sed -i.tmp "s|RESULTS_PLACEHOLDER|$results_html|g" "$OUTPUT_FILE"
}
    
    # Clean up temp files
    rm -f "$OUTPUT_FILE.tmp" "$temp_file"
}

# Main function
main() {
    parse_arguments "$@"
    check_dependencies
    
    log_info "HTML Report Generator starting..."
    log_verbose "Configuration: input=$INPUT_FILE, output=$OUTPUT_FILE, title=$TITLE"
    
    generate_html_report
    
    log_success "HTML report generated: $OUTPUT_FILE"
    log_info "Open in browser: file://$(realpath "$OUTPUT_FILE")"
}

# Execute main function
main "$@"