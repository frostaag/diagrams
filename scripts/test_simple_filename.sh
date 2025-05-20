#!/bin/bash
# Test processing simple numeric filename

set -e

echo "Testing processing of simple numeric filename..."
echo "Current directory: $(pwd)"

# Create a test file if it doesn't exist
if [ ! -f "drawio_files/70.drawio" ]; then
  echo "Creating test file drawio_files/70.drawio..."
  cp "drawio_files/59 (041).drawio" "drawio_files/70.drawio"
  echo "Test file created."
fi

# Process the test file
echo "Processing drawio_files/70.drawio..."
./scripts/process_drawio_file.sh "drawio_files/70.drawio"

# Check if output files were created
if [ -f "html_files/70.html" ] && [ -f "svg_files/70.svg" ]; then
  echo "✅ Success: Output files created!"
else
  echo "❌ Error: Output files not created."
  exit 1
fi

# Check if changelog entry was added
if grep -q "70.drawio" "html_files/CHANGELOG.csv"; then
  echo "✅ Success: Changelog entry added!"
else
  echo "❌ Error: Changelog entry not added."
  exit 1
fi

echo "Test completed successfully!"
