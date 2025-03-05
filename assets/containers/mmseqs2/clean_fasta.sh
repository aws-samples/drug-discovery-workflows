#!/bin/bash

# Check if input file is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <input_file>"
  exit 1
fi

# Get input file name and path
input_file="$1"

# Check if input file exists
if [ ! -f "$input_file" ]; then
  echo "Error: File '$input_file' not found"
  exit 1
fi

# Create output filename
filename=$(basename -- "$input_file")
extension="${filename##*.}"
output_file="clean.${extension}"

# Process the file with our awk command
awk '
  /^>/ { 
    if ($0 ~ /^>(glycan|ligand|rna|dna)\|/) {
      skip = 1
    } else {
      skip = 0
      # Transform headers with "protein|name=" prefix
      if ($0 ~ /^>protein\|name=/) {
        sub(/^>protein\|name=/, ">")
        print
      # Transform headers with "protein|" prefix
      } else if ($0 ~ /^>protein\|/) {
        sub(/^>protein\|/, ">")
        print
      # Keep other headers unchanged
      } else {
        print
      }
    }
  }
  !/^>/ {
    if (skip == 0) print
  }
' "$input_file" >"$output_file"

echo "Processing complete. Output saved to: $output_file"
