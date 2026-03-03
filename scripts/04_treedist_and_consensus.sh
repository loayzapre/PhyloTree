#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 1. Directories
# --------------------------------------------------

ALIGN_DIR="data/alignments"
TREE_DIR="data/trees"
REPORT_DIR="data/reports"

mkdir -p "$REPORT_DIR"

# --------------------------------------------------
# 2. Trees generated in step 03
# --------------------------------------------------

TREES=(
    "$TREE_DIR/clustalw_parsimony.tre"
    "$TREE_DIR/clustalw_nj.tre"
    "$TREE_DIR/mafft_parsimony.tre"
    "$TREE_DIR/mafft_nj.tre"
    "$TREE_DIR/muscle_parsimony.tre"
    "$TREE_DIR/muscle_nj.tre"
)

# --------------------------------------------------
# 3. Any nexus file (only used to define taxa)
# --------------------------------------------------

DATA_FILE="$ALIGN_DIR/clustalw.nexus"

[[ -f "$DATA_FILE" ]] || { echo "ERROR: Nexus file not found: $DATA_FILE"; exit 1; }

# --------------------------------------------------
# 4. PAUP executable
# --------------------------------------------------

PAUP_BIN="/usr/local/bin/paup4a169"

[[ -x "$PAUP_BIN" ]] || { echo "ERROR: PAUP executable not found"; exit 1; }

export LD_LIBRARY_PATH="$HOME/opt/paup-compat/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

echo "Using PAUP executable: $PAUP_BIN"
echo

# --------------------------------------------------
# 5. Run comparison
# --------------------------------------------------

echo "Starting Tree Comparison Analysis..."

"$PAUP_BIN" <<EOF

execute $DATA_FILE;

gettrees file=${TREES[0]} mode=7;
gettrees file=${TREES[1]} mode=7;
gettrees file=${TREES[2]} mode=7;
gettrees file=${TREES[3]} mode=7;
gettrees file=${TREES[4]} mode=7;
gettrees file=${TREES[5]} mode=7;

[Tree distance matrix]
treedist method=symmetric;

[Consensus tree]
contree all / majrule=yes showtreedist=yes;

savetrees file=$REPORT_DIR/consensus.tre format=altnex replace=yes;

quit;

EOF

echo
echo "------------------------------------------"
echo "Tree comparison complete"
echo "Consensus tree saved in:"
echo "$REPORT_DIR/consensus.tre"
echo "------------------------------------------"