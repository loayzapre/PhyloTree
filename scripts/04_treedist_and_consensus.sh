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
# 2. Trees (6) produced by step 03
# --------------------------------------------------

TREES=(
    "$TREE_DIR/clustalw.trim_parsimony.tre"
    "$TREE_DIR/clustalw.trim_nj.tre"
    "$TREE_DIR/mafft.trim_parsimony.tre"
    "$TREE_DIR/mafft.trim_nj.tre"
    "$TREE_DIR/muscle.trim_parsimony.tre"
    "$TREE_DIR/muscle.trim_nj.tre"
)

# --------------------------------------------------
# 3. Any NEXUS alignment (only for taxa definitions)
# --------------------------------------------------

DATA_FILE="$ALIGN_DIR/clustalw.trim.nexus"

# --------------------------------------------------
# 4. PAUP executable + required libs
# --------------------------------------------------

PAUP_BIN="/usr/local/bin/paup4a169"

if [[ ! -x "$PAUP_BIN" ]]; then
    echo "ERROR: PAUP executable not found at $PAUP_BIN" >&2
    exit 1
fi

export LD_LIBRARY_PATH="$HOME/opt/paup-compat/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

# --------------------------------------------------
# 5. Checks
# --------------------------------------------------

[[ -f "$DATA_FILE" ]] || { echo "ERROR: Missing DATA_FILE: $DATA_FILE" >&2; exit 1; }

for t in "${TREES[@]}"; do
    [[ -f "$t" ]] || { echo "ERROR: Missing tree file: $t" >&2; exit 1; }
done

echo "Using PAUP executable: $PAUP_BIN"
echo
echo "Starting Tree Comparison Analysis..."

# --------------------------------------------------
# 6. Run PAUP
# --------------------------------------------------

"$PAUP_BIN" <<EOF

execute $DATA_FILE;

[Load trees]
gettrees file=${TREES[0]} mode=7;
gettrees file=${TREES[1]} mode=7;
gettrees file=${TREES[2]} mode=7;
gettrees file=${TREES[3]} mode=7;
gettrees file=${TREES[4]} mode=7;
gettrees file=${TREES[5]} mode=7;

[Activate outgroup]
outgroup Xenopus_laevis;
set root=outgroup outroot=monophyl;

[Root all loaded trees]
roottrees;

[Distance matrix]
treedist;

[Majority-rule consensus]
contree all / strict=no majrule=yes percent=50;

[Save only the consensus tree]
savetrees file=$REPORT_DIR/consensus.tre format=altnex brlens=yes replace=yes from=7 to=7;

log stop;

quit;
EOF

echo
echo "------------------------------------------"
echo "Tree comparison complete"
echo "Log saved to:       $REPORT_DIR/paup_commands.log"
echo "Consensus saved to: $REPORT_DIR/consensus.tre"
echo "------------------------------------------"