#!/usr/bin/env bash
set -euo pipefail

# Activate micromamba environment
eval "$(micromamba shell hook --shell bash)"
micromamba activate phylo

echo "===================================="
echo "Phylogenetic Pipeline"
echo "===================================="
echo

# --------------------------------------------------
# Parse command-line arguments
# --------------------------------------------------
# Tree methods available: ml, parsimony, nj, mrbayes
# Note: Add "mrbayes" to $3 if Bayesian inference desired (very slow)

INPUT_FASTA="${1:-data/raw/sequences.fsa}"
ALIGN_METHODS="${2:-mafft,muscle,clustalw}"
TREE_METHODS="${3:-ml,parsimony,nj,mrbayes}"
OUTDIR="${4:-data}"

# Validate input file
if [[ ! -f "$INPUT_FASTA" ]]; then
    echo "ERROR: Input FASTA file not found: $INPUT_FASTA" >&2
    exit 1
fi

echo "Configuration:"
echo "  Input FASTA    : $INPUT_FASTA"
echo "  Alignment methods: $ALIGN_METHODS"
echo "  Tree methods    : $TREE_METHODS"
echo "  Output base dir : $OUTDIR"
echo

# --------------------------------------------------
# Step 1 — Multiple Sequence Alignment
# --------------------------------------------------
echo "[1/5] Running sequence alignments..."
bash scripts/01_align.sh "$INPUT_FASTA" "$ALIGN_METHODS"
echo "✓ Alignments completed"
echo

# --------------------------------------------------
# Step 2 — Convert alignments to NEXUS
# --------------------------------------------------
echo "[2/5] Converting alignments to NEXUS format..."
bash scripts/02_convert_to_nexus.sh
echo "✓ NEXUS files created"
echo

# --------------------------------------------------
# Step 3 — Build trees
# --------------------------------------------------
echo "[3/5] Running tree inference ($TREE_METHODS)..."
bash scripts/03_build_trees.sh "$TREE_METHODS"
echo "✓ Trees generated"
echo

# --------------------------------------------------
# Step 4 — Tree distance + consensus
# --------------------------------------------------
echo "[4/5] Computing tree distances and consensus..."
bash scripts/04_treedist_and_consensus.sh
echo "✓ Tree comparison completed"
echo

# --------------------------------------------------
# Step 5 — Export figures
# --------------------------------------------------
echo "[5/5] Exporting tree figures..."
python scripts/05_export_figtrees.py
echo "✓ Figures exported"
echo

echo "===================================="
echo "Pipeline finished successfully"
echo "===================================="
