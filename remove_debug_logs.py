#!/usr/bin/env python3
"""
DCFlight Debug Log Removal Script
Removes debug print statements from Dart and Swift files for production release.
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Tuple

class DebugLogCleaner:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.dart_files_processed = 0
        self.swift_files_processed = 0
        self.total_lines_removed = 0
        
        # Dart patterns to remove
        self.dart_patterns = [
            # Simple print statements
            r'^\s*print\s*\([^)]*\)\s*;\s*$',
            # debugPrint statements
            r'^\s*debugPrint\s*\([^)]*\)\s*;\s*$',
            # developer.log statements
            r'^\s*developer\.log\s*\([^)]*\)\s*;\s*$',
            # Simple if kDebugMode single line
            r'^\s*if\s*\(\s*kDebugMode\s*\)\s*print\s*\([^)]*\)\s*;\s*$',
        ]
        
        # Swift patterns to remove
        self.swift_patterns = [
            # Simple print statements
            r'^\s*print\s*\([^)]*\)\s*$',
            # NSLog statements
            r'^\s*NSLog\s*\([^)]*\)\s*$',
            # os_log statements
            r'^\s*os_log\s*\([^)]*\)\s*$',
        ]
    
    def clean_dart_file(self, file_path: Path) -> int:
        """Clean debug statements from a Dart file."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            original_count = len(lines)
            cleaned_lines = []
            i = 0
            
            while i < len(lines):
                line = lines[i]
                
                # Check for if (kDebugMode) blocks
                if re.match(r'^\s*if\s*\(\s*kDebugMode\s*\)\s*\{\s*$', line):
                    # Skip until we find the closing brace
                    brace_count = 1
                    i += 1
                    while i < len(lines) and brace_count > 0:
                        next_line = lines[i]
                        brace_count += next_line.count('{') - next_line.count('}')
                        i += 1
                    continue
                
                # Check against simple patterns
                should_remove = False
                for pattern in self.dart_patterns:
                    if re.match(pattern, line):
                        should_remove = True
                        break
                
                if not should_remove:
                    cleaned_lines.append(line)
                
                i += 1
            
            lines_removed = original_count - len(cleaned_lines)
            
            if lines_removed > 0:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(cleaned_lines)
                print(f"  ✓ Removed {lines_removed} debug lines from {file_path.name}")
                self.total_lines_removed += lines_removed
            
            self.dart_files_processed += 1
            return lines_removed
            
        except Exception as e:
            print(f"  ❌ Error processing {file_path.name}: {e}")
            return 0
    
    def clean_swift_file(self, file_path: Path) -> int:
        """Clean debug statements from a Swift file."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            original_count = len(lines)
            cleaned_lines = []
            i = 0
            
            while i < len(lines):
                line = lines[i]
                
                # Check for #if DEBUG blocks
                if re.match(r'^\s*#if\s+DEBUG\s*$', line):
                    # Skip until we find #endif
                    i += 1
                    while i < len(lines):
                        next_line = lines[i]
                        if re.match(r'^\s*#endif\s*$', next_line):
                            i += 1
                            break
                        i += 1
                    continue
                
                # Check against simple patterns
                should_remove = False
                for pattern in self.swift_patterns:
                    if re.match(pattern, line):
                        should_remove = True
                        break
                
                if not should_remove:
                    cleaned_lines.append(line)
                
                i += 1
            
            lines_removed = original_count - len(cleaned_lines)
            
            if lines_removed > 0:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(cleaned_lines)
                print(f"  ✓ Removed {lines_removed} debug lines from {file_path.name}")
                self.total_lines_removed += lines_removed
            
            self.swift_files_processed += 1
            return lines_removed
            
        except Exception as e:
            print(f"  ❌ Error processing {file_path.name}: {e}")
            return 0
    
    def find_files(self, pattern: str) -> List[Path]:
        """Find files matching the given pattern."""
        files = []
        for file_path in self.project_root.rglob(pattern):
            # Skip hidden directories and files
            if any(part.startswith('.') for part in file_path.parts):
                continue
            if file_path.is_file():
                files.append(file_path)
        return files
    
    def run(self) -> None:
        """Run the debug log cleanup process."""
        print("🧹 DCFlight Debug Log Cleanup Script")
        print("====================================")
        print(f"Scanning project at: {self.project_root}")
        print()
        
        # Process Dart files
        print("Processing Dart files...")
        dart_files = self.find_files("*.dart")
        for file_path in dart_files:
            self.clean_dart_file(file_path)
        
        print()
        
        # Process Swift files
        print("Processing Swift files...")
        swift_files = self.find_files("*.swift")
        for file_path in swift_files:
            self.clean_swift_file(file_path)
        
        print()
        print("Summary:")
        print("=" * 20)
        print(f"Dart files processed: {self.dart_files_processed}")
        print(f"Swift files processed: {self.swift_files_processed}")
        print(f"Total debug lines removed: {self.total_lines_removed}")
        
        if self.total_lines_removed > 0:
            print()
            print("✅ Debug log cleanup completed successfully!")
            print("💡 Tip: Run 'git diff' to review the changes before committing.")
        else:
            print()
            print("ℹ️  No debug statements found to remove.")

def main():
    if len(sys.argv) > 1:
        project_root = sys.argv[1]
    else:
        # Use the directory where the script is located
        script_dir = Path(__file__).parent
        project_root = script_dir
    
    cleaner = DebugLogCleaner(project_root)
    cleaner.run()

if __name__ == "__main__":
    main()
