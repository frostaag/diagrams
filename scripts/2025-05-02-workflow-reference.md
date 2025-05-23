# DrawIO Conversion Workflow Reference (May 2, 2025)

This document contains the current GitHub Actions workflow script used for converting Draw.io diagrams to SVG and HTML formats, creating a changelog, and uploading to SharePoint.

> **Note**: This reference was updated on May 2, 2025 to fix a syntax error in the SharePoint upload script where there was a duplicate closing bracket in the `formattedRow` array.

## Purpose

This script automatically processes all modified Draw.io files, converts them to SVG format, creates HTML wrappers, and maintains a detailed changelog with version tracking and commit hash references.

## Key Features

- Processes files with spaces in their names
- Tracks file changes using Git integration
- Extracts commit hashes for change tracking
- Maintains a comprehensive changelog
- Converts diagrams using the Draw.io CLI
- Detects new vs. modified diagrams
- Implements versioning (1.0, 1.1, 2.0, etc.)
- Uploads the changelog to SharePoint

## Current Implementation (as of May 2, 2025)

Below is the complete GitHub Actions workflow:

```yaml
# GitHub Actions Workflow - drawio-convert.yml
name: Convert Draw.io Files

on:
  push:
    paths:
      - '**/*.drawio'
      - 'drawio_files/**'
  # Allow manual triggering
  workflow_dispatch:

jobs:
  convert:
    runs-on: ubuntu-latest
    steps:
      # Step 1: Check out the repository with history to detect changes
      - name: Check out the repository
        uses: actions/checkout@v3
        with:
          fetch-depth: 0 # Fetch all history to properly identify changed files

      # Step 2: Install dependencies
      - name: Install Draw.io and dependencies
        run: |
          sudo apt-get update
          # Use libasound2t64 instead of libasound2 for Ubuntu Noble (24.04)
          sudo apt-get install -y wget unzip xvfb libasound2t64 libgbm1 libnspr4 libnss3 libxss1
          wget https://github.com/jgraph/drawio-desktop/releases/download/v26.2.2/drawio-amd64-26.2.2.deb
          sudo apt-get -f install -y
          sudo dpkg -i drawio-amd64-26.2.2.deb || sudo apt-get -f install -y
          
      # Step 2.5: Add .drawio extension to files without extension
      - name: Add .drawio extension to files without extension
        run: |
          # Check if drawio_files directory exists
          if [ -d "drawio_files" ]; then
            echo "Checking for files without extension in drawio_files directory..."
            
            # First, make sure we have the latest changes from remote
            echo "Fetching latest changes from remote repository..."
            git fetch "https://${{ github.actor }}:${{ secrets.GITHUB_TOKEN }}@github.com/${{ github.repository }}.git"
            
            # Find files without extension in drawio_files directory
            # Use find command with null separator to handle filenames with spaces
            find drawio_files -type f -not -path "*/\.*" -print0 | while IFS= read -r -d $'\0' file; do
              # Check if filename contains a dot (which indicates an extension)
              filename=$(basename "$file")
              if [[ "$filename" != *.* ]]; then
                # Check if the file actually exists before trying to rename it
                if [ -f "$file" ]; then
                  echo "Adding .drawio extension to: $file"
                  
                  # Check if target file already exists (in case we've already renamed it)
                  if [ -f "${file}.drawio" ]; then
                    echo "Warning: ${file}.drawio already exists. Skipping rename."
                  else
                    # Check if file is a drawing
                    file_type=$(file -b "$file" | grep -i "xml" || echo "")
                    if [[ -n "$file_type" || $(head -c 100 "$file" | grep -q "mxfile") ]]; then
                      echo "File appears to be a draw.io diagram. Renaming..."
                      # Rename the file
                      mv "$file" "${file}.drawio"
                      
                      # Add and commit the renamed file
                      git add "${file}.drawio"
                      # Also remove the original file if git still tracks it
                      git rm --ignore-unmatch "$file" > /dev/null 2>&1
                      
                      git config --local user.name "github-actions[bot]"
                      git config --local user.email "github-actions[bot]@users.noreply.github.com"
                      git commit -m "Add .drawio extension to $filename"
                      
                      # Push changes immediately to avoid conflicts
                      echo "Pushing changes to remote repository..."
                      git push "https://${{ github.actor }}:${{ secrets.GITHUB_TOKEN }}@github.com/${{ github.repository }}.git" HEAD:${GITHUB_REF#refs/heads/}
                    fi
                  fi
                else
                  echo "Warning: File $file no longer exists, skipping."
                fi
              fi
            done
          else
            echo "drawio_files directory not found, skipping extension check."
          fi
          
      # Step 3: Create output directories
      - name: Create output folders
        run: |
          mkdir -p svg_files html_files
          
          # Initialize CSV changelog with headers if it doesn't exist - now with commit hash column
          if [ ! -f "html_files/CHANGELOG.csv" ]; then
            echo "Date,Time,User,Diagram,Action,File,Commit Message,Version,Commit Hash" > html_files/CHANGELOG.csv
          fi
          # No longer creating changelog in svg_files folder

      # Step 4: Convert .drawio files to SVG and wrap them in HTML
      - name: Convert Draw.io files
        run: |
          # Set up virtual display for headless operation
          Xvfb :99 -screen 0 1024x768x16 &
          export DISPLAY=:99
          sleep 1 # Give Xvfb time to start

          # Use a different approach - temporary script
          cat > /tmp/convert-drawio.sh << 'EOL'
          #!/bin/bash
          input_file=$1
          output_file=$2
          drawio -x -f svg -o "$output_file" "$input_file"
          EOL
          chmod +x /tmp/convert-drawio.sh

          # Create a file to track processed files to avoid duplicates
          > /tmp/processed_files.txt
          
          # Function to safely process filenames with spaces
          process_diagram_file() {
            local file_to_process="$1"
            echo "===== Processing: $file_to_process ====="
            
            # Check if this file has already been processed
            if grep -q "^$file_to_process\$" /tmp/processed_files.txt; then
              echo "File $file_to_process has already been processed in this run, skipping."
              return 3
            fi
            
            # Skip if file doesn't exist
            if [ ! -f "$file_to_process" ]; then
              echo "File $file_to_process no longer exists, skipping."
              return 1
            fi
            
            # Check if this file was actually changed in the current commit
            local was_changed=false
            
            # Method 1: Check changed files list
            grep -q "^$file_to_process\$" /tmp/changed_files.txt && was_changed=true
            
            # Method 2: Direct git diff check (backup if grep fails due to special chars)
            if [ "$was_changed" = false ]; then
              git diff --name-only HEAD^ HEAD 2>/dev/null | grep -q "^$file_to_process\$" && was_changed=true
            fi
            
            # Special case for first commit or files specifically targeted
            if [ ! -s /tmp/changed_files.txt ] || grep -q "^$file_to_process\$" /tmp/files_with_spaces.txt; then
              was_changed=true
            fi
            
            if [ "$was_changed" = false ]; then
              echo "File $file_to_process was not changed in this commit, skipping."
              return 2
            fi
            
            echo "Confirmed $file_to_process was changed in this commit. Processing..."
            
            # Get the base filename without extension, preserving spaces
            local base_name=$(basename "$file_to_process" .drawio)
            echo "Base name: $base_name"
            
            # Create output directories if they don't exist
            mkdir -p "svg_files" "html_files"
            local output_svg="svg_files/${base_name}.svg"
            
            # Convert to SVG
            echo "Converting to SVG..."
            xvfb-run -a /tmp/convert-drawio.sh "$file_to_process" "$output_svg"
            
            # Check if conversion succeeded
            if [ ! -f "$output_svg" ]; then
              echo "First conversion method failed. Trying alternative method..."
              xvfb-run -a drawio -x -f svg -o "$output_svg" "$file_to_process"
              
              # If still failed, show more information
              if [ ! -f "$output_svg" ]; then
                echo "ERROR: Both conversion methods failed for $file_to_process"
                echo "File info:"
                ls -la "$file_to_process"
                echo "Content preview:"
                head -c 100 "$file_to_process" | hexdump -C
                return 1
              fi
            fi
            
            echo "Successfully converted to SVG!"
            
            # Create HTML wrapper
            echo "Creating HTML wrapper..."
            local output_html="html_files/${base_name}.html"
            echo '<!DOCTYPE html>' > "$output_html"
            echo '<html lang="en">' >> "$output_html"
            echo '<head>' >> "$output_html"
            echo '  <meta charset="UTF-8">' >> "$output_html"
            echo "  <title>${base_name}</title>" >> "$output_html"
            echo '  <style>' >> "$output_html"
            echo '    body { margin: 0; padding: 0; }' >> "$output_html"
            echo '    svg { max-width: 100%; height: auto; display: block; }' >> "$output_html"
            echo '  </style>' >> "$output_html"
            echo '</head>' >> "$output_html"
            echo '<body>' >> "$output_html"
            cat "$output_svg" >> "$output_html"
            echo '</body>' >> "$output_html"
            echo '</html>' >> "$output_html"
            
            # Get commit information
            local author=$(git log -1 --format="%aN" -- "$file_to_process" 2>/dev/null || echo "GitHub Actions")
            local commit_msg=$(git log -1 --format="%s" -- "$file_to_process" 2>/dev/null || echo "Processing file with spaces")
            local commit_msg_escaped=$(echo "$commit_msg" | sed 's/"/""/g')
            local formatted_date=$(date +"%d.%m.%Y")
            local formatted_time=$(date +"%H:%M:%S")
            local short_hash=$(git log -1 --pretty=format:"%h" -- "$file_to_process" 2>/dev/null || echo "manual")
            
            # Determine if this is new or modified
            local change_type="New"
            local git_history=$(git log --follow --pretty=format:"%h %s" -- "$file_to_process")
            local commit_count=$(echo "$git_history" | wc -l | tr -d ' ')
            
            if [ "$commit_count" -gt 1 ]; then
              change_type="Modified"
              local action_desc="Modified (Update)"
            else
              local action_desc="New"
            fi
            
            # Calculate version
            local version="1.0"
            if [ "$change_type" = "Modified" ]; then
              # Simple calculation: first update is 1.1, and so on
              local minor_version=$((commit_count - 1))
              version="1.${minor_version}"
            fi
            
            # Add changelog entry
            echo "$formatted_date,$formatted_time,\"$author\",\"${base_name}\",\"$action_desc\",\"${base_name}.drawio to ${base_name}.html\",\"$commit_msg_escaped\",\"$version\",\"$short_hash\"" >> html_files/CHANGELOG.csv
            echo "Added entry to changelog for $file_to_process ($action_desc) with version $version"
            
            # Mark this file as processed to avoid duplicates
            echo "$file_to_process" >> /tmp/processed_files.txt
            
            return 0
          }

          # Set debug output to help troubleshoot
          echo "Current directory: $(pwd)"
          echo "Listing drawio_files directory:"
          ls -la drawio_files || echo "drawio_files directory not found"
          
          # Get the list of changed .drawio files in the current commit
          # Use newline separated list to handle spaces in filenames
          git diff --name-only HEAD^ HEAD 2>/dev/null | grep -E "\.drawio$" > /tmp/changed_files.txt || echo "" > /tmp/changed_files.txt
          
          # If HEAD^ fails (first commit), try against empty tree
          if [ ! -s /tmp/changed_files.txt ]; then
            git diff-tree --name-only --no-commit-id --root -r HEAD | grep -E "\.drawio$" > /tmp/changed_files.txt || echo "" > /tmp/changed_files.txt
          fi
          
          echo "Files changed in this commit:"
          cat /tmp/changed_files.txt
          
          # Look for changed files with spaces
          echo "Checking for changed files with spaces in their names..."
          
          # Create a file to store changed files with spaces
          > /tmp/files_with_spaces.txt
          
          # Process each file in changed_files.txt to find those with spaces
          if [ -s /tmp/changed_files.txt ]; then
            while IFS= read -r file; do
              if [[ "$file" == *" "* ]]; then
                echo "Found changed file with spaces: $file"
                echo "$file" >> /tmp/files_with_spaces.txt
              fi
            done < /tmp/changed_files.txt
          fi
          
          # If no changed files were detected, we need to check if this commit is explicitly
          # for a file with spaces that might have been missed by git diff
          if [ ! -s /tmp/changed_files.txt ]; then
            # Get the commit message of the current commit
            CURRENT_COMMIT_MSG=$(git log -1 --format="%s")
            echo "Current commit message: $CURRENT_COMMIT_MSG"
            
            # If commit mentions a file with spaces, add it to our processing list
            if [[ "$CURRENT_COMMIT_MSG" == *"Diagram Test Git"* ]] || 
               [[ "$CURRENT_COMMIT_MSG" == *"Test Diag"* ]] ||
               [[ "$CURRENT_COMMIT_MSG" == *"Untitled Diagram"* ]]; then
              
              # Extract the likely filename from the commit message
              for part in $CURRENT_COMMIT_MSG; do
                if [[ -f "drawio_files/$part.drawio" ]]; then
                  echo "Found file mentioned in commit: drawio_files/$part.drawio"
                  echo "drawio_files/$part.drawio" >> /tmp/changed_files.txt
                  echo "drawio_files/$part.drawio" >> /tmp/files_with_spaces.txt
                fi
              done
            fi
          fi
          
          # Process any changed files with spaces first
          if [ -s /tmp/files_with_spaces.txt ]; then
            echo "========================================="
            echo "PROCESSING CHANGED FILES WITH SPACES IN THEIR NAMES"
            echo "========================================="
            while IFS= read -r space_file || [ -n "$space_file" ]; do
              echo "Processing changed file with spaces: $space_file"
              process_diagram_file "$space_file"
            done < /tmp/files_with_spaces.txt
          else
            echo "No changed files with spaces detected in this commit."
          fi

          # Now process remaining changed files (skipping those with spaces that were already processed)
          echo "========================================="
          echo "PROCESSING REMAINING CHANGED FILES"
          echo "========================================="
          
          # Create a temporary file for files without spaces
          > /tmp/files_without_spaces.txt
          
          # Filter out files that were already processed (those with spaces)
          while IFS= read -r changed_file || [ -n "$changed_file" ]; do
            # Skip files with spaces since they've already been processed
            if [[ "$changed_file" != *" "* ]]; then
              echo "$changed_file" >> /tmp/files_without_spaces.txt
            fi
          done < /tmp/changed_files.txt
          
          # Read line by line to process files without spaces
          while IFS= read -r changed_file || [ -n "$changed_file" ]; do
            # Use our dedicated function to process the file
            echo "Processing file without spaces: $changed_file"
            process_diagram_file "$changed_file"

            # NOTE: This part is no longer needed as the process_diagram_file function handles all this
            # HTML creation, changelog updates, etc. are now handled by the function
            
            # For backwards compatibility, we'll still set these variables
            # but the actual processing is done in the process_diagram_file function
            base=$(basename "$changed_file" .drawio)
            FILE_CHANGED=true
            AUTHOR=$(git log -1 --format="%aN" -- "$changed_file" 2>/dev/null || echo "${{ github.actor }}")
            COMMIT_MSG=$(git log -1 --format="%s" -- "$changed_file" 2>/dev/null || echo "No commit message")
            COMMIT_MSG=$(echo "$COMMIT_MSG" | sed 's/"/""/g')
            FORMATTED_DATE=$(date +"%d.%m.%Y")
            FORMATTED_TIME=$(date +"%H:%M:%S")
              
              # Check if this is a new diagram or a modification
              # First try with git history, fallback to file existence check
              if git ls-files --error-unmatch "svg_files/${base}.svg" &>/dev/null 2>/dev/null; then
                CHANGE_TYPE="Modified"
              else
                # Fallback to direct file check before our current conversion
                if [ -f "svg_files/${base}.svg.old" ]; then
                  CHANGE_TYPE="Modified"
                else
                  CHANGE_TYPE="New"
                fi
              fi
              
              # Make sure changelog directory exists
              mkdir -p svg_files html_files
              
              # Make debug output to understand what's happening
              echo "Creating changelog entries for: $base (${CHANGE_TYPE})"
              
              # Get enhanced version information using semantic versioning light (MAJOR.MINOR)
              # Use git history to determine if this is a major or minor change
              # Start with the commit message - if it contains keywords, categorize the change
              MAJOR_KEYWORDS="redesign|new version|complete|refactor|overhaul|major|added"
              MINOR_UPDATE_KEYWORDS="update|fix|adjust|tweak|enhance|improve|minor"
              
              # Default to standard minor change (increment minor version)
              IS_MAJOR_CHANGE=0
              CHANGE_DESCRIPTION="Change"
              
              # Check commit message for major change keywords (case insensitive)
              if echo "$COMMIT_MSG" | grep -iE "$MAJOR_KEYWORDS" > /dev/null; then
                IS_MAJOR_CHANGE=1
                CHANGE_DESCRIPTION="Major Change"
                echo "Detected major change based on commit message keywords"
              # Check for minor update keywords (case insensitive)
              elif echo "$COMMIT_MSG" | grep -iE "$MINOR_UPDATE_KEYWORDS" > /dev/null; then
                CHANGE_DESCRIPTION="Update"
                echo "Detected update based on commit message keywords"
              fi
              
              # Get file-specific history count for versioning
              echo "Looking for commit history of: $changed_file"
              # Store version history in a variable
              FILE_COMMIT_HISTORY=$(git log --follow --pretty=format:"%h %s" -- "$changed_file")
              echo "File commit history:"
              echo "$FILE_COMMIT_HISTORY"
              
              # Count file-specific commits only
              FILE_COMMIT_COUNT=$(echo "$FILE_COMMIT_HISTORY" | wc -l | tr -d ' ')
              echo "File has $FILE_COMMIT_COUNT commits in its history"
              
              # This section is now handled by the process_diagram_file function
              # But we'll maintain compatibility with the existing workflow by
              # setting variables that might be used elsewhere
              
              # Set default versions based on our improved logic
              MINOR_VERSION=$FILE_COMMIT_COUNT
              MAJOR_VERSION=1
              
              # For version calculation, we now use the simpler approach from our function
              if [ "$CHANGE_TYPE" = "New" ]; then
                VERSION="1.0"
              else
                # If this is the first update, it's 1.1, and so on
                MINOR_NUM=$((FILE_COMMIT_COUNT - 1))
                VERSION="1.${MINOR_NUM}"
              fi
              
              # Set action description
              if [ "$CHANGE_TYPE" = "New" ]; then
                ACTION_DESC="New"
              else
                ACTION_DESC="Modified (Update)"
              fi
              
              # These values are now informational only, as the actual changelog
              # entry was created by the process_diagram_file function
              COMMIT_HASH=$(git log -1 --pretty=format:"%H" -- "$changed_file" 2>/dev/null || echo "manual")
              SHORT_HASH=$(git log -1 --pretty=format:"%h" -- "$changed_file" 2>/dev/null || echo "manual")
              
              # The changelog entry has already been written by the process_diagram_file function
              echo "Processed $changed_file with version $VERSION (hash: $SHORT_HASH)"
            
          done < /tmp/files_without_spaces.txt

      # Step 5: Commit and push changes
      - name: Commit and push changes
        id: commit_changes
        run: |
          git config --local user.name "github-actions[bot]"
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          
          # Fetch latest changes before adding our changes
          echo "Fetching latest changes from remote repository..."
          git fetch origin
          
          # Add our changes
          git add svg_files html_files
          
          # Check if there are changes to commit
          if git diff --cached --quiet; then
            echo "No changes to commit"
            echo "changes_made=false" >> $GITHUB_OUTPUT
          else
            git commit -m "Auto-converted draw.io files"
            
            # Pull the latest changes before pushing
            echo "Pulling latest changes from remote repository..."
            git pull --rebase origin ${GITHUB_REF#refs/heads/}
            
            # Use GitHub token for authentication and push
            echo "Pushing changes to remote repository..."
            git push "https://${{ github.actor }}:${{ secrets.GITHUB_TOKEN }}@github.com/${{ github.repository }}.git" HEAD:${GITHUB_REF#refs/heads/}
            echo "changes_made=true" >> $GITHUB_OUTPUT
          fi
          
      # Step 6: Upload changelog to SharePoint
      - name: Upload changelog to SharePoint
        if: steps.commit_changes.outputs.changes_made == 'true'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const path = require('path');
            
            try {
              const https = require('https');
              console.log('Preparing to upload changelog to SharePoint...');
              
              // Read and format the changelog file for SharePoint
              const changelogPath = path.join(process.env.GITHUB_WORKSPACE, 'html_files', 'CHANGELOG.csv');
              console.log(`Reading changelog from: ${changelogPath}`);
              const rawContent = fs.readFileSync(changelogPath, 'utf8');
              
              // Format the changelog with proper headers and content
              // First, parse the existing CSV
              const lines = rawContent.split('\n').filter(line => line.trim());
              const header = lines[0]; // Get header row
              const dataRows = lines.slice(1); // Get data rows
              
              // Create a properly formatted CSV with all the needed columns in the requested order
              // Date, Time, Diagram, Action, File, Commit Message, Version, Commit Hash
              let fileContent = 'Date,Time,Diagram,Action,File,Commit Message,Version,Commit Hash\n';
              
              // Add the data rows with today's upload date
              const today = new Date().toLocaleDateString('en-GB', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric'
              }); // Format as DD.MM.YYYY
              
              // Process each row to handle the changed column ordering
              dataRows.forEach(row => {
                if (row.trim()) {
                  // Using a more robust CSV parsing approach
                  try {
                    // First, parse the CSV properly using a regex that handles quoted fields with commas
                    const parseCSV = (text) => {
                      const result = [];
                      const regex = /("[^"]*"|[^,"\r\n]+)(?=,|\r\n|$)|^(?=,|$)|,(?=,|$)/g;
                      let m;
                      
                      while ((m = regex.exec(text)) !== null) {
                        // Remove quotes if the field is quoted
                        let field = m[1] || '';
                        if (field.startsWith('"') && field.endsWith('"')) {
                          field = field.substring(1, field.length - 1);
                        }
                        result.push(field);
                      }
                      
                      return result;
                    };
                    
                    const extractedCols = parseCSV(row);
                    
                    // Ensure we have enough columns and handle missing values
                    while (extractedCols.length < 9) {
                      extractedCols.push('');
                    }
                    
                    // For reference, original columns are:
                    // [0]Date, [1]Time, [2]User, [3]Diagram, [4]Action, [5]File, [6]Commit Message, [7]Version, [8]Commit Hash
                    
                    // Keeping same format, just removing the SharePoint Upload Date:
                    // [0]Date, [1]Time, [2]Diagram, [3]Action, [4]File, [5]Commit Message, [6]Version, [7]Commit Hash
                    
                    // Create a properly formatted CSV row with quotes around each field
                    const formattedRow = [
                      extractedCols[0],                      // Date
                      extractedCols[1],                      // Time
                      `"${(extractedCols[3] || '').replace(/"/g, '""')}"`,  // Diagram
                      `"${(extractedCols[4] || '').replace(/"/g, '""')}"`,  // Action
                      `"${(extractedCols[5] || '').replace(/"/g, '""')}"`,  // File
                      `"${(extractedCols[6] || '').replace(/"/g, '""')}"`,  // Commit Message
                      extractedCols[7] || '',                // Version
                      extractedCols[8] || ''                 // Commit Hash
                    ].join(',');
                    
                    fileContent += formattedRow + '\n';
                  } catch (error) {
                    console.error(`Error processing CSV row: ${row}`, error);
                    // Skip this row if there's an error
                  }
                }
              });
              
              console.log(`Formatted changelog with ${dataRows.length} entries`);
              
              // Function to make HTTP requests with promises
              const httpRequest = (options, postData) => {
                return new Promise((resolve, reject) => {
                  const req = https.request(options, (res) => {
                    let data = '';
                    res.on('data', (chunk) => { data += chunk; });
                    res.on('end', () => {
                      if (res.statusCode >= 200 && res.statusCode < 300) {
                        try {
                          const parsedData = data ? JSON.parse(data) : {};
                          resolve(parsedData);
                        } catch (e) {
                          console.error('Error parsing response:', e);
                          resolve(data); // Return raw data if not JSON
                        }
                      } else {
                        reject(new Error(`Request failed with status code ${res.statusCode}: ${data}`));
                      }
                    });
                  });
                  
                  req.on('error', reject);
                  
                  if (postData) {
                    req.write(postData);
                  }
                  req.end();
                });
              };
              
              // Step 1: Get access token with proper SharePoint permissions
              console.log('Getting access token...');
              const tokenBody = new URLSearchParams({
                client_id: process.env.CLIENT_ID,
                scope: 'https://graph.microsoft.com/.default',
                client_secret: process.env.CLIENT_SECRET,
                grant_type: 'client_credentials'
              }).toString();
              
              const tokenOptions = {
                method: 'POST',
                hostname: 'login.microsoftonline.com',
                path: `/${process.env.TENANT_ID}/oauth2/v2.0/token`,
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Content-Length': Buffer.byteLength(tokenBody)
                }
              };
              
              // Get token
              const tokenData = await httpRequest(tokenOptions, tokenBody);
              console.log('Access token obtained');
              
              // Step 2: Get drives if needed
              // Force drive ID detection regardless of configured value due to previous errors
              console.log('Attempting to detect SharePoint drives automatically...');
              
              // Verify the site ID from secrets
              try {
                console.log(`Verifying site ID from secret: ${process.env.SITE_ID}`);
                
                const siteOptions = {
                  method: 'GET',
                  hostname: 'graph.microsoft.com',
                  path: `/v1.0/sites/${process.env.SITE_ID}`,
                  headers: {
                    'Authorization': `Bearer ${tokenData.access_token}`
                  }
                };
                
                const siteData = await httpRequest(siteOptions);
                console.log(`Site found: ${siteData.displayName || siteData.name}`);
              } catch (siteError) {
                console.error('Error verifying site:', siteError.message);
                console.log('Trying alternative site path format...');
                
                // If the site ID doesn't work, try a different format
                const originalSiteId = process.env.SITE_ID;
                try {
                  // Try sites/SiteName format
                  if (!originalSiteId.startsWith('sites/')) {
                    process.env.SITE_ID = `sites/${originalSiteId.split('/').pop()}`;
                    console.log(`Using alternative site ID format: ${process.env.SITE_ID}`);
                  } else {
                    console.error('Unable to find site with provided ID');
                    throw siteError;
                  }
                } catch (formatError) {
                  console.error('Error reformatting site ID:', formatError.message);
                  throw siteError;
                }
              }
              
              // Now get the list of drives
              const drivesOptions = {
                method: 'GET',
                hostname: 'graph.microsoft.com',
                path: `/v1.0/sites/${process.env.SITE_ID}/drives`,
                headers: {
                  'Authorization': `Bearer ${tokenData.access_token}`
                }
              };
              
              console.log(`Requesting drives list from: ${drivesOptions.path}`);
              const drivesData = await httpRequest(drivesOptions);
              
              if (!drivesData.value || drivesData.value.length === 0) {
                throw new Error(`No drives found for site ID: ${process.env.SITE_ID}`);
              }
              
              console.log('Available drives:');
              drivesData.value.forEach(d => console.log(`- ${d.name}: ${d.id}`));
              
              // Try to find the Documents drive - prioritize "Shared Documents" 
              console.log('Looking for document library named "Shared Documents"');
              const documentsDrive = drivesData.value.find(d => 
                d.name === 'Shared Documents' || 
                d.name === 'Documents' ||
                d.name === 'Shared Files' ||
                d.name === 'Shared'
              );
              
              let driveId;
              if (documentsDrive) {
                driveId = documentsDrive.id;
                console.log(`Selected document library: ${documentsDrive.name} (${driveId})`);
              } else {
                // If no specific document library found, use the first drive
                driveId = drivesData.value[0].id;
                console.log(`Using first available drive: ${drivesData.value[0].name} (${driveId})`);
              }
              
              // Create the target path - folder structure
              const targetFolder = process.env.SHAREPOINT_FOLDER || 'Diagrams'; // Default to 'Diagrams' if not specified
              
              // Step 3: Create the folder if it doesn't exist
              console.log(`Ensuring folder exists: ${targetFolder}`);
              
              try {
                // Try to get the folder to see if it exists
                const folderOptions = {
                  method: 'GET',
                  hostname: 'graph.microsoft.com',
                  path: `/v1.0/drives/${driveId}/root:/${encodeURIComponent(targetFolder)}`,
                  headers: {
                    'Authorization': `Bearer ${tokenData.access_token}`
                  }
                };
                
                await httpRequest(folderOptions);
                console.log(`Folder ${targetFolder} already exists.`);
              } catch (folderError) {
                // Folder doesn't exist, create it
                console.log(`Creating folder ${targetFolder}...`);
                
                const createFolderOptions = {
                  method: 'POST',
                  hostname: 'graph.microsoft.com',
                  path: `/v1.0/drives/${driveId}/root/children`,
                  headers: {
                    'Authorization': `Bearer ${tokenData.access_token}`,
                    'Content-Type': 'application/json'
                  }
                };
                
                const folderData = JSON.stringify({
                  name: targetFolder,
                  folder: {},
                  '@microsoft.graph.conflictBehavior': 'rename'
                });
                
                await httpRequest(createFolderOptions, folderData);
                console.log(`Folder ${targetFolder} created successfully.`);
              }
              
              // Step 4: Upload the changelog file
              const filename = 'CHANGELOG.csv';
              console.log(`Uploading ${filename} to ${targetFolder}...`);
              
              const uploadOptions = {
                method: 'PUT',
                hostname: 'graph.microsoft.com',
                path: `/v1.0/drives/${driveId}/root:/${encodeURIComponent(targetFolder)}/${encodeURIComponent(filename)}:/content`,
                headers: {
                  'Authorization': `Bearer ${tokenData.access_token}`,
                  'Content-Type': 'text/csv',
                  'Content-Length': Buffer.byteLength(fileContent)
                }
              };
              
              const uploadResult = await httpRequest(uploadOptions, fileContent);
              console.log(`File uploaded successfully to SharePoint. WebUrl: ${uploadResult.webUrl}`);
              
            } catch (error) {
              console.error('Error uploading to SharePoint:', error.message);
              // Don't fail the build if SharePoint upload fails
            }
```

## Changelog Format

The CHANGELOG.csv file has the following columns:

| Column | Description |
|--------|-------------|
| Date | The date when the change was processed (dd.mm.yyyy) |
| Time | The time when the change was processed (hh:mm:ss) |
| User | The Git username of the person who made the change |
| Diagram | The name of the diagram without extension |
| Action | Either "New" or "Modified (Update)" |
| File | The conversion path (e.g., "diagram.drawio to diagram.html") |
| Commit Message | The Git commit message associated with the change |
| Version | The calculated version number (e.g., "1.0", "1.1", "2.0") |
| Commit Hash | The short Git commit hash for tracking |
