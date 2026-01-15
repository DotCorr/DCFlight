#!/bin/bash
echo "Cleaning Xcode caches..."

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean module cache
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

# Clean build folder
rm -rf build

# Clean Pods
rm -rf Pods Podfile.lock

# Reinstall
pod install


