#!/usr/bin/env bash
set -euo pipefail

echo "===================================="
echo "Phylogenetic Pipeline"
echo "===================================="
echo

# --------------------------------------------------
# Step 1 — Multiple Sequence Alignment
# --------------------------------------------------
echo "[1/5] Running sequence alignments..."
bash scripts/01_align.sh
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
# Step 3 — Build trees with PAUP
# --------------------------------------------------
echo "[3/5] Running PAUP tree inference..."
bash scripts/03_run_paup.sh
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
echo "Results located in:"
echo "  data/trees/"
echo "  data/reports/"
echo "===================================="