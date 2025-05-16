#!/bin/bash
# Script to manually process a drawio file without waiting for the workflow
# Usage: ./process_drawio_file.sh path/to/file.drawio

set -e

if [ -z "$1" ]; then
  echo "Error: No file specified"
  echo "Usage: $0 path/to/file.drawio"
  exit 1
fi

FILE_PATH="$1"
if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File not found: $FILE_PATH"
  exit 1
fi

echo "Processing $FILE_PATH..."

# Create output directories
mkdir -p svg_files html_files

# Initialize CHANGELOG.csv if it doesn't exist
if [ ! -f "html_files/CHANGELOG.csv" ]; then
  echo "Date,Time,Diagram,File,Action,Commit Message,Version,Commit Hash" > html_files/CHANGELOG.csv
  echo "Initialized CHANGELOG.csv with headers"
fi

# Get base name
base=$(basename "$FILE_PATH" .drawio)
output_svg="svg_files/${base}.svg"
output_html="html_files/${base}.html"

# Check if we have drawio installed
if ! command -v drawio &> /dev/null; then
  echo "Error: drawio command not found"
  echo "Creating placeholder files instead"
  echo '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480">' > "$output_svg"
  echo '  <rect width="100%" height="100%" fill="#ffffcc"/>' >> "$output_svg"
  echo '  <text x="10" y="20" font-family="Arial" font-size="16">Manual processing (drawio tool not available)</text>' >> "$output_svg"
  echo '  <text x="10" y="45" font-family="Arial" font-size="12">This is a placeholder SVG file</text>' >> "$output_svg"
  echo '</svg>' >> "$output_svg"
else
  # Convert to SVG
  echo "Converting to SVG..."
  if drawio -x -f svg -o "$output_svg" "$FILE_PATH" 2>/dev/null; then
    echo "✅ Successfully converted to SVG: $output_svg"
  else
    echo "❌ Failed to convert with drawio, trying with xvfb-run if available..."
    if command -v xvfb-run &> /dev/null; then
      if xvfb-run --auto-servernum --server-args="-screen 0 1280x1024x24" drawio -x -f svg -o "$output_svg" "$FILE_PATH" 2>/dev/null; then
        echo "✅ Successfully converted to SVG with xvfb-run: $output_svg"
      else
        echo "❌ Failed to convert: $FILE_PATH"
        # Create a placeholder SVG for failed conversions
        echo '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480">' > "$output_svg"
        echo '  <rect width="100%" height="100%" fill="#ffffcc"/>' >> "$output_svg"
        echo '  <text x="10" y="20" font-family="Arial" font-size="16">Error: Failed to convert diagram</text>' >> "$output_svg"
        echo '  <text x="10" y="45" font-family="Arial" font-size="12">Please check the file and try again</text>' >> "$output_svg"
        echo '</svg>' >> "$output_svg"
      fi
    else
      echo "❌ xvfb-run not available"
      # Create a placeholder SVG
      echo '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480">' > "$output_svg"
      echo '  <rect width="100%" height="100%" fill="#ffffcc"/>' >> "$output_svg"
      echo '  <text x="10" y="20" font-family="Arial" font-size="16">Error: xvfb-run not available</text>' >> "$output_svg"
      echo '  <text x="10" y="45" font-family="Arial" font-size="12">Please install xvfb or use the workflow</text>' >> "$output_svg"
      echo '</svg>' >> "$output_svg"
    fi
  fi
fi

# Only create HTML wrapper if SVG exists
if [ -f "$output_svg" ]; then
  echo "Creating HTML wrapper..."
  echo '<!DOCTYPE html>' > "$output_html"
  echo '<html lang="en">' >> "$output_html"
  echo '<head>' >> "$output_html"
  echo '  <meta charset="UTF-8">' >> "$output_html"
  echo "  <title>$base</title>" >> "$output_html"
  echo '  <style>body { margin: 0; padding: 0; } svg { max-width: 100%; height: auto; display: block; }</style>' >> "$output_html"
  echo '</head>' >> "$output_html"
  echo '<body>' >> "$output_html"
  cat "$output_svg" >> "$output_html"
  echo '</body>' >> "$output_html"
  echo '</html>' >> "$output_html"
  
  # Add entry to changelog
  CHANGELOG_ENTRY="$(date +"%d.%m.%Y"),$(date +"%H:%M:%S"),\"$base\",\"$FILE_PATH\",\"Manual Conversion\",\"Manually processed\",\"1.0\",\"manual\""
  echo "Adding changelog entry: $CHANGELOG_ENTRY"
  echo "$CHANGELOG_ENTRY" >> html_files/CHANGELOG.csv
  
  echo "✅ Successfully created HTML file: $output_html"
  echo "✅ Added entry to changelog"
else
  echo "❌ SVG output missing, skipping HTML wrapper"
fi

echo "Done!"
