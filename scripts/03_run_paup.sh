#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# 1. Directories
# --------------------------------------------------

ALIGN_DIR="data/alignments"
TREE_DIR="data/trees"

mkdir -p "$TREE_DIR"

# --------------------------------------------------
# 2. Alignment base names (without extension)
# --------------------------------------------------

ALIGN_FILES=("clustalw" "mafft" "muscle")

INPUT_FILES=()

for f in "${ALIGN_FILES[@]}"; do
    INPUT_FILES+=("$ALIGN_DIR/${f}.nexus")
done

# --------------------------------------------------
# 3. Outgroups
# --------------------------------------------------

OUTGROUPS=("MW417983.1" "PX623998.1")
OUTGROUP_STR="${OUTGROUPS[*]}"

# --------------------------------------------------
# 4. PAUP executable
# --------------------------------------------------

PAUP_BIN="/usr/local/bin/paup4a169"

if [[ ! -x "$PAUP_BIN" ]]; then
    echo "ERROR: PAUP executable not found at $PAUP_BIN"
    exit 1
fi

# This matches the wrapper function you had
export LD_LIBRARY_PATH="$HOME/opt/paup-compat/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

echo "Using PAUP executable: $PAUP_BIN"
echo

# --------------------------------------------------
# 5. Run analyses
# --------------------------------------------------

for FILE in "${INPUT_FILES[@]}"; do

    if [[ ! -f "$FILE" ]]; then
        echo "ERROR: File not found: $FILE"
        exit 1
    fi

    BASE="$(basename "${FILE%.*}")"

    echo "--------------------------------------------------"
    echo "Processing $FILE"
    echo "Outgroups: $OUTGROUP_STR"
    echo "--------------------------------------------------"

    "$PAUP_BIN" <<EOF
execute $FILE;

outgroup $OUTGROUP_STR;
set root=outgroup;

[Parsimony tree]
set criterion=parsimony;
hsearch addseq=random nreps=10 swap=tbr;
savetrees file=$TREE_DIR/${BASE}_parsimony.tre format=altnex brlens=yes replace=yes;

cleartrees;

[Neighbour Joining tree]
set criterion=distance;
dset distance=hky;
nj;
savetrees file=$TREE_DIR/${BASE}_nj.tre format=altnex brlens=yes replace=yes;

quit;
EOF

done

echo
echo "------------------------------------------"
echo "Finished!"
echo "Trees saved in $TREE_DIR"
echo "------------------------------------------"