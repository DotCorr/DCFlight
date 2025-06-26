#!/bin/bash

# DCFlight Debug Log Removal Script
# This script removes debug print statements from Dart and Swift files
# Targets: print(), debugPrint(), if (kDebugMode) { print() }, and Swift print()

set -e

echo "🧹 DCFlight Debug Log Cleanup Script"
echo "===================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
dart_files_processed=0
swift_files_processed=0
total_lines_removed=0

echo -e "${BLUE}Scanning project at: $PROJECT_ROOT${NC}"
echo

# Function to remove debug prints from Dart files
clean_dart_file() {
    local file="$1"
    local temp_file=$(mktemp)
    local lines_removed=0
    local original_lines=$(wc -l < "$file")
    
    # Remove various Dart debug print patterns
    # 1. Simple print() statements
    # 2. debugPrint() statements  
    # 3. if (kDebugMode) { print() } blocks (single and multi-line)
    # 4. developer.log() statements
    
    # Use sed to remove debug statements
    sed -E \
        -e '/^[[:space:]]*print\(/d' \
        -e '/^[[:space:]]*debugPrint\(/d' \
        -e '/^[[:space:]]*developer\.log\(/d' \
        -e '/^[[:space:]]*if[[:space:]]*\([[:space:]]*kDebugMode[[:space:]]*\)[[:space:]]*\{[[:space:]]*$/,/^[[:space:]]*\}[[:space:]]*$/d' \
        -e '/^[[:space:]]*if[[:space:]]*\([[:space:]]*kDebugMode[[:space:]]*\)[[:space:]]*\{.*print.*\}[[:space:]]*$/d' \
        -e '/^[[:space:]]*if[[:space:]]*\([[:space:]]*kDebugMode[[:space:]]*\)[[:space:]]*print/d' \
        "$file" > "$temp_file"
    
    # More sophisticated removal using awk for complex cases
    awk '
    BEGIN { 
        in_debug_block = 0
        brace_count = 0
    }
    
    # Detect start of kDebugMode block
    /if[[:space:]]*\([[:space:]]*kDebugMode[[:space:]]*\)/ {
        if ($0 ~ /\{/) {
            in_debug_block = 1
            brace_count = 1
            # Count opening braces in the same line
            gsub(/[^{]/, "", temp)
            brace_count += length(temp) - 1
            next
        }
    }
    
    # Handle braces within debug blocks
    in_debug_block == 1 {
        # Count braces
        opening = gsub(/\{/, "{", $0)
        closing = gsub(/\}/, "}", $0)
        brace_count += opening - closing
        
        if (brace_count <= 0) {
            in_debug_block = 0
            brace_count = 0
        }
        next
    }
    
    # Skip simple debug statements
    /^[[:space:]]*print\(/ { next }
    /^[[:space:]]*debugPrint\(/ { next }
    /^[[:space:]]*developer\.log\(/ { next }
    
    # Print all other lines
    in_debug_block == 0 { print }
    ' "$temp_file" > "${temp_file}.awk"
    
    mv "${temp_file}.awk" "$temp_file"
    
    local new_lines=$(wc -l < "$temp_file")
    lines_removed=$((original_lines - new_lines))
    
    if [ $lines_removed -gt 0 ]; then
        mv "$temp_file" "$file"
        echo -e "  ${GREEN}✓${NC} Removed $lines_removed debug lines from $(basename "$file")"
        total_lines_removed=$((total_lines_removed + lines_removed))
    else
        rm "$temp_file"
    fi
    
    dart_files_processed=$((dart_files_processed + 1))
}

# Function to remove debug prints from Swift files
clean_swift_file() {
    local file="$1"
    local temp_file=$(mktemp)
    local lines_removed=0
    local original_lines=$(wc -l < "$file")
    
    # Remove Swift debug print patterns
    # 1. print() statements
    # 2. NSLog() statements
    # 3. #if DEBUG blocks (more complex, handled separately)
    
    # Use sed to remove debug statements
    sed -E \
        -e '/^[[:space:]]*print\(/d' \
        -e '/^[[:space:]]*NSLog\(/d' \
        -e '/^[[:space:]]*os_log\(/d' \
        "$file" > "$temp_file"
    
    # Handle #if DEBUG blocks with awk
    awk '
    BEGIN { 
        in_debug_block = 0
    }
    
    # Detect start of DEBUG block
    /^[[:space:]]*#if[[:space:]]+DEBUG/ {
        in_debug_block = 1
        next
    }
    
    # Detect end of DEBUG block
    /^[[:space:]]*#endif/ && in_debug_block == 1 {
        in_debug_block = 0
        next
    }
    
    # Skip lines within debug blocks
    in_debug_block == 1 { next }
    
    # Print all other lines
    in_debug_block == 0 { print }
    ' "$temp_file" > "${temp_file}.awk"
    
    mv "${temp_file}.awk" "$temp_file"
    
    local new_lines=$(wc -l < "$temp_file")
    lines_removed=$((original_lines - new_lines))
    
    if [ $lines_removed -gt 0 ]; then
        mv "$temp_file" "$file"
        echo -e "  ${GREEN}✓${NC} Removed $lines_removed debug lines from $(basename "$file")"
        total_lines_removed=$((total_lines_removed + lines_removed))
    else
        rm "$temp_file"
    fi
    
    swift_files_processed=$((swift_files_processed + 1))
}

# Process Dart files
echo -e "${YELLOW}Processing Dart files...${NC}"
while IFS= read -r -d '' file; do
    clean_dart_file "$file"
done < <(find "$PROJECT_ROOT" -name "*.dart" -type f -not -path "*/.*" -print0)

echo

# Process Swift files
echo -e "${YELLOW}Processing Swift files...${NC}"
while IFS= read -r -d '' file; do
    clean_swift_file "$file"
done < <(find "$PROJECT_ROOT" -name "*.swift" -type f -not -path "*/.*" -print0)

echo
echo -e "${BLUE}Summary:${NC}"
echo "===================="
echo -e "Dart files processed: ${GREEN}$dart_files_processed${NC}"
echo -e "Swift files processed: ${GREEN}$swift_files_processed${NC}"
echo -e "Total debug lines removed: ${GREEN}$total_lines_removed${NC}"

if [ $total_lines_removed -gt 0 ]; then
    echo
    echo -e "${GREEN}✅ Debug log cleanup completed successfully!${NC}"
    echo -e "${YELLOW}💡 Tip: Run 'git diff' to review the changes before committing.${NC}"
else
    echo
    echo -e "${BLUE}ℹ️  No debug statements found to remove.${NC}"
fi
