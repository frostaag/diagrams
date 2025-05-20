# Diagrams Workflow

This project provides automated conversion of draw.io diagrams to SVG and HTML formats, with version tracking and changelog generation.

## Overview

The workflow does the following:

1. **Converts draw.io files**: Any `.drawio` file in the `drawio_files` folder will be converted to SVG format and stored in the `svg_files` folder.
2. **Creates HTML viewers**: Each SVG file is wrapped in an HTML viewer for easy viewing in browsers.
3. **Tracks changes**: All conversions are tracked in a changelog CSV file with version numbering.
4. **Uploads to SharePoint**: The changelog is uploaded to SharePoint for team reference.

## File Naming Conventions

The workflow supports two naming conventions:

1. **Simple numeric filenames**: `70.drawio`, `71.drawio`, etc.
2. **Files with IDs**: `Name (001).drawio`, where the 3-digit number in parentheses is the ID.

## How to Use

### Adding New Diagrams

1. Create your diagram in draw.io.
2. Save it in the `drawio_files` folder with one of the supported naming conventions.
3. Commit and push your changes.
4. GitHub Actions will automatically convert the file and update the changelog.

### Processing Existing Files Manually

If you need to process files locally without waiting for GitHub Actions, use the provided script:

```bash
./scripts/process-drawio.sh drawio_files/70.drawio
```

Optional flags:
- `-v` or `--verbose`: Show detailed processing information
- `-p` or `--preview`: Open the HTML output in a browser after processing

### Triggering the Workflow Manually

You can also manually trigger the workflow from GitHub:

1. Go to the Actions tab in the repository
2. Select the "Convert Draw.io Files (Simplified)" workflow
3. Click "Run workflow"
4. Optionally specify a particular file to process

## Version Tracking

The system automatically tracks versions in the format `X.Y`:

- Minor version (Y) is incremented for normal changes.
- Major version (X) is incremented when commit messages contain keywords like "major", "redesign", "breaking", or "release".

## Changelog

The changelog is stored in `html_files/CHANGELOG.csv` with the following columns:

- Date
- Time
- Diagram
- File
- Action
- Commit Message
- Version
- Commit Hash

## Folder Structure

- `drawio_files/`: Source draw.io diagram files
- `svg_files/`: Generated SVG files
- `html_files/`: Generated HTML viewers
- `scripts/`: Helper scripts for the workflow
