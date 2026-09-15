#!/usr/bin/env python3
"""Repository entry point for the packaged native iOS verifier."""
from pathlib import Path
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.ios_verification import main, export_records

if __name__ == '__main__':
    raise SystemExit(main())
