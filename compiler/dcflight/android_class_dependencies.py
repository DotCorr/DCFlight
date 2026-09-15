"""Inspect JVM class references for prohibited application runtime dependencies."""
import re


def dependency_references(listing):
    references=re.findall(r'^\s*#\d+\s*=\s*Class\s+#\d+\s+//\s+(\S+)',listing,re.MULTILINE)
    forbidden=('dcflight/','dart/','io/flutter/','com/facebook/react/','org/mozilla/javascript/')
    return sorted({name for name in references if name.lstrip('[').removeprefix('L').rstrip(';').lower().startswith(forbidden)})

