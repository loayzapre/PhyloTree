#!/usr/bin/bash

# 1. Configuration
INPUT_FILES=("data/alignments/clustalw.trim.fasta" "data/alignments/mafft.trim.fasta" "data/alignments/muscle.trim.fasta")
OUTPUT_DIR="data/alignments"  # Change this to your preferred path

# 2. Create the output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# 3. Process files
for FILE in "${INPUT_FILES[@]}"
do
    if [[ -f "$FILE" ]]; then
        # Get the base name (remove path and extension)
        # Example: "./data/whale.fasta" -> "whale"
        BASE_NAME=$(basename "${FILE%.*}")
        
        # Define the full output path
        OUTPUT_PATH="$OUTPUT_DIR/${BASE_NAME}.nexus"
        
        echo "Converting $FILE -> $OUTPUT_PATH"

        # Execute seqconverter
        seqconverter --informat fasta --outformat nexus -i "$FILE" > "$OUTPUT_PATH"

        if [ $? -eq 0 ]; then
            echo "Success: Saved to $OUTPUT_PATH"
        else
            echo "Error: Failed to process $FILE"
        fi
    else
        echo "Warning: $FILE not found."
    fi
done

echo "--------------------------------------"
echo "Done. All files are in: $OUTPUT_DIR"