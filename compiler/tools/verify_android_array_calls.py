#!/usr/bin/env python3
"""Repository entry point for the packaged Android scalar/array execution checks."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.android_verification import cases, run, main

if __name__ == '__main__':
    main()
