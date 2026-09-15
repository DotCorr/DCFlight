#!/usr/bin/env python3
"""Checkout entry point for the installed dcflight SDK availability verifier."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dcflight.android_availability_verification import main, verify

if __name__ == '__main__':
    sys.exit(main())
