#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 1. Directories
# --------------------------------------------------

ALIGN_DIR="${1:-data/alignments}"
TREE_DIR="${2:-data/trees}"
REPORT_DIR="${3:-data/reports}"

mkdir -p "$REPORT_DIR"

# --------------------------------------------------
# 2. Settings
# --------------------------------------------------

OUTGROUP="${OUTGROUP:-Xenopus_laevis}"

# --------------------------------------------------
# 3. PAUP executable
# --------------------------------------------------

PAUP_BIN="${PAUP_BIN:-/usr/local/bin/paup4a169}"

if [[ ! -x "$PAUP_BIN" ]]; then
    echo "ERROR: PAUP executable not found at $PAUP_BIN" >&2
    exit 1
fi

export LD_LIBRARY_PATH="$HOME/opt/paup-compat/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

# --------------------------------------------------
# 4. Dynamically find tree files
# --------------------------------------------------

shopt -s nullglob
TREE_FILES=("$TREE_DIR"/*.tre)
[[ ${#TREE_FILES[@]} -gt 0 ]] || { echo "WARNING: No .tre files found in $TREE_DIR" >&2; exit 0; }

# --------------------------------------------------
# 5. Find a NEXUS alignment for taxa definitions
# --------------------------------------------------

DATA_FILE=""
shopt -s nullglob
for nex in "$ALIGN_DIR"/*.trim.nexus; do
    [[ -f "$nex" ]] && DATA_FILE="$nex" && break
done

[[ -f "$DATA_FILE" ]] || { echo "ERROR: No NEXUS alignment file found in $ALIGN_DIR" >&2; exit 1; }

echo "Using PAUP executable: $PAUP_BIN"
echo "Data file: $DATA_FILE"
echo "Found ${#TREE_FILES[@]} tree file(s)"
echo
echo "Starting Tree Comparison Analysis..."
echo

# --------------------------------------------------
# 6. Build gettrees commands
# --------------------------------------------------

GETTREES_CMD=""
for tree_file in "${TREE_FILES[@]}"; do
    GETTREES_CMD="${GETTREES_CMD}gettrees file=$tree_file mode=7;"$'\n'
done

# --------------------------------------------------
# 7. Run PAUP
# --------------------------------------------------

"$PAUP_BIN" <<EOF

execute $DATA_FILE;

[Load all trees]
$GETTREES_CMD

[Activate outgroup]
outgroup $OUTGROUP;
set root=outgroup outroot=monophyl;

[Root all loaded trees]
roottrees;

[Distance matrix]
treedist;

[Majority-rule consensus]
contree all / strict=no majrule=yes percent=50 treefile=$REPORT_DIR/consensus.tre replace=yes;

log stop;

quit;
EOF

echo
echo "------------------------------------------"
echo "Tree comparison complete"
echo "Consensus saved to: $REPORT_DIR/consensus.tre"
echo "------------------------------------------"