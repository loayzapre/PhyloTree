#!/usr/bin/bash
set -euo pipefail

# 02_convert_to_nexus.sh
# Dynamically converts all trimmed FASTA alignments to NEXUS format
# Scans data/alignments for *.trim.fasta files

INPUT_DIR="${1:-data/alignments}"
OUTPUT_DIR="${2:-data/alignments}"

# Create the output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo

command -v seqconverter >/dev/null 2>&1 || { echo "ERROR: seqconverter not found (pip install seqconverter)" >&2; exit 1; }

# Dynamically find all .trim.fasta files
shopt -s nullglob
for FILE in "$INPUT_DIR"/*.trim.fasta; do
    [[ -f "$FILE" ]] || { echo "Warning: No trimmed FASTA files found in $INPUT_DIR"; exit 0; }
    
    # Get the base name (remove path and .trim.fasta extension)
    BASE_NAME=$(basename "$FILE" .trim.fasta)
    
    # Define the full output path
    OUTPUT_PATH="$OUTPUT_DIR/${BASE_NAME}.trim.nexus"
    
    echo "Converting $FILE -> $OUTPUT_PATH"

    # Execute seqconverter
    seqconverter --informat fasta --outformat nexus -i "$FILE" > "$OUTPUT_PATH"

    if [ $? -eq 0 ]; then
        echo "  ✓ Success: Saved to $OUTPUT_PATH"
    else
        echo "  ✗ Error: Failed to process $FILE" >&2
        exit 1
    fi
done

echo
echo "--------------------------------------"
echo "Done. NEXUS files saved to: $OUTPUT_DIR"
echo "--------------------------------------"