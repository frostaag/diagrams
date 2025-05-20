#!/bin/bash
# Script to test the workflow changes locally

set -e

echo "Testing workflow file updates for simple numeric filenames..."

# Make sure we have 70.drawio in place
if [ ! -f "drawio_files/70.drawio" ]; then
  echo "Creating test file drawio_files/70.drawio..."
  cp "drawio_files/59 (041).drawio" "drawio_files/70.drawio"
  echo "Test file created."
fi

# Test the file pattern detection
echo "Testing file pattern detection..."
echo "Files matching the pattern 'drawio_files/* ([0-9][0-9][0-9]).drawio':"
find drawio_files -name "* ([0-9][0-9][0-9]).drawio" | sort

echo "Files matching the pattern 'drawio_files/[0-9]*.drawio':"
find drawio_files -name "[0-9]*.drawio" | sort

echo "\nCombined pattern (using -o for OR):"
find drawio_files -name "* ([0-9][0-9][0-9]).drawio" -o -name "[0-9]*.drawio" | sort

# Simulate the workflow's file detection logic
echo "\nSimulating workflow file detection logic..."
touch /tmp/test_changed_files.txt

# Check for files with pattern "* (###).drawio"
find drawio_files -name "* ([0-9][0-9][0-9]).drawio" -mtime -1 | sort >> /tmp/test_changed_files.txt

# Also check for simple numeric filenames like "70.drawio"
find drawio_files -name "[0-9]*.drawio" -mtime -1 | sort >> /tmp/test_changed_files.txt

echo "Files detected ($(wc -l < /tmp/test_changed_files.txt) files):"
cat /tmp/test_changed_files.txt || echo "No files found or error reading file"

# Check if 70.drawio is detected
if grep -q "70.drawio" /tmp/test_changed_files.txt; then
  echo "✅ Success: 70.drawio is detected by the pattern!"
else
  echo "❌ Error: 70.drawio is NOT detected by the pattern."
  exit 1
fi

echo "Test completed successfully!"
