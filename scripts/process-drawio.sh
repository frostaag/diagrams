#!/bin/bash
# Manual processor for drawio files - simplifies conversion without waiting for GitHub Actions

# Set default values
VERBOSE=false
FILE_PATH=""
PREVIEW=false

# Function to display usage information
show_usage() {
  echo "Usage: $0 [options] path/to/file.drawio"
  echo ""
  echo "Options:"
  echo "  -v, --verbose     Display detailed processing information"
  echo "  -p, --preview     Open the HTML output in a browser after processing"
  echo "  -h, --help        Display this help message"
  echo ""
  echo "Example:"
  echo "  $0 -v drawio_files/70.drawio"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -p|--preview)
      PREVIEW=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      if [[ -z "$FILE_PATH" ]]; then
        FILE_PATH="$1"
      else
        echo "Error: Too many arguments"
        show_usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Check if file path is provided
if [ -z "$FILE_PATH" ]; then
  echo "Error: Missing file path"
  show_usage
  exit 1
fi

# Verify file exists
if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File not found: $FILE_PATH"
  exit 1
fi

# Function for verbose output
log() {
  if [ "$VERBOSE" = true ]; then
    echo "$1"
  fi
}

# Create output directories if they don't exist
mkdir -p svg_files html_files

# Initialize CHANGELOG.csv if it doesn't exist
if [ ! -f "html_files/CHANGELOG.csv" ]; then
  echo "Date,Time,Diagram,File,Action,Commit Message,Version,Commit Hash" > html_files/CHANGELOG.csv
  log "Initialized CHANGELOG.csv with headers"
fi

# Get base name for output files
base=$(basename "$FILE_PATH" .drawio)
output_svg="svg_files/${base}.svg"
output_html="html_files/${base}.html"

log "Processing: $FILE_PATH"
log "Output SVG: $output_svg"
log "Output HTML: $output_html"

# Check if drawio command is available
if command -v drawio &> /dev/null; then
  log "Using drawio command to convert file"
  # Convert to SVG
  if drawio -x -f svg -o "$output_svg" "$FILE_PATH" 2>/dev/null; then
    echo "✅ Successfully converted to SVG"
  else
    log "Failed with direct drawio command, trying with xvfb-run..."
    # Try with xvfb-run if available
    if command -v xvfb-run &> /dev/null; then
      if xvfb-run --auto-servernum --server-args="-screen 0 1280x1024x24" drawio -x -f svg -o "$output_svg" "$FILE_PATH" 2>/dev/null; then
        echo "✅ Successfully converted to SVG with xvfb-run"
      else
        echo "❌ Failed to convert file"
        create_placeholder=true
      fi
    else
      echo "⚠️ xvfb-run not available, cannot convert in headless mode"
      create_placeholder=true
    fi
  fi
else
  echo "⚠️ drawio command not available, creating placeholder SVG"
  create_placeholder=true
fi

# Create placeholder SVG if needed
if [ "$create_placeholder" = true ]; then
  log "Creating placeholder SVG"
  cat > "$output_svg" << EOL
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480">
  <rect width="100%" height="100%" fill="#ffffcc"/>
  <text x="10" y="20" font-family="Arial" font-size="16">Manual Processing Only</text>
  <text x="10" y="45" font-family="Arial" font-size="12">drawio command not available</text>
</svg>
EOL
fi

# Create HTML wrapper
if [ -f "$output_svg" ]; then
  log "Creating HTML wrapper"
  cat > "$output_html" << EOL
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${base}</title>
  <style>
    body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
    svg { max-width: 100%; height: auto; display: block; }
    .container { padding: 20px; }
    .info { margin-top: 20px; background: #f8f9fa; padding: 15px; border-radius: 5px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>${base}</h1>
    <div class="svg-container">
EOL
  cat "$output_svg" >> "$output_html"
  cat >> "$output_html" << EOL
    </div>
    <div class="info">
      <p>Manually processed on: $(date)</p>
      <p>Source file: ${FILE_PATH}</p>
    </div>
  </div>
</body>
</html>
EOL

  echo "✅ Created HTML file: $output_html"
  
  # Add entry to changelog
  CHANGELOG_ENTRY="$(date +"%d.%m.%Y"),$(date +"%H:%M:%S"),\"$base\",\"$FILE_PATH\",\"Manual Conversion\",\"Manually processed\",\"1.0\",\"manual\""
  log "Adding changelog entry: $CHANGELOG_ENTRY"
  echo "$CHANGELOG_ENTRY" >> html_files/CHANGELOG.csv
  
  # Open in browser if requested
  if [ "$PREVIEW" = true ]; then
    log "Opening HTML file in browser"
    if command -v open &> /dev/null; then
      open "$output_html"  # macOS
    elif command -v xdg-open &> /dev/null; then
      xdg-open "$output_html"  # Linux
    elif command -v start &> /dev/null; then
      start "$output_html"  # Windows
    else
      echo "⚠️ Could not open browser automatically, please open: $output_html"
    fi
  fi
else
  echo "❌ Failed to create SVG file"
  exit 1
fi

echo "✅ Done! Files created:"
echo "  - $output_svg"
echo "  - $output_html"
echo "  - Entry added to html_files/CHANGELOG.csv"
