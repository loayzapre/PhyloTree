#!/usr/bin/env bash
set -euo pipefail

# 03_build_trees.sh
# Unified tree building script supporting multiple methods:
#  - ml: Maximum Likelihood (iqtree3)
#  - parsimony: Parsimony (PAUP)
#  - nj: Neighbor Joining (PAUP)
#  - mrbayes: Bayesian (MrBayes)

TREE_METHODS="${1:-ml,parsimony,nj}"
ALIGN_DIR="${2:-data/alignments}"
TREE_DIR="${3:-data/trees}"
REPORT_DIR="${4:-data/reports}"
TMP_DIR="${5:-data/tmp_mrbayes}"

# Parse methods array
IFS=',' read -ra METHODS <<< "$TREE_METHODS"

# Convert to lowercase and validate
run_ml=0
run_parsimony=0
run_nj=0
run_mrbayes=0

for method in "${METHODS[@]}"; do
    method=$(echo "$method" | xargs | tr '[:upper:]' '[:lower:]')
    case "$method" in
        ml|iqtree)     run_ml=1 ;;
        parsimony|paup) run_parsimony=1 ;;
        nj|neighbor)   run_nj=1 ;;
        bayes|mrbayes) run_mrbayes=1 ;;
    esac
done

mkdir -p "$TREE_DIR" "$REPORT_DIR" "$TMP_DIR"

die() { echo "ERROR: $*" >&2; exit 1; }

# --------------------------------------------------
# Detect available tools
# --------------------------------------------------

IQTREE_BIN="${IQTREE_BIN:-iqtree3}"
PAUP_BIN="${PAUP_BIN:-/usr/local/bin/paup4a169}"
MRBAYES_BIN="${MRBAYES_BIN:-mb}"
SUMT_BIN="${SUMT_BIN:-sumt}"

have_iqtree=0
have_paup=0
have_mrbayes=0
have_sumt=0

command -v "$IQTREE_BIN" >/dev/null 2>&1 && have_iqtree=1
[[ -x "$PAUP_BIN" ]] && have_paup=1
command -v "$MRBAYES_BIN" >/dev/null 2>&1 && have_mrbayes=1
command -v "$SUMT_BIN" >/dev/null 2>&1 && have_sumt=1

# Validate tool availability
[[ $run_ml -eq 1 && $have_iqtree -eq 0 ]] && die "IQ-TREE not found: $IQTREE_BIN"
[[ $run_mrbayes -eq 1 && $have_mrbayes -eq 0 ]] && die "MrBayes not found: $MRBAYES_BIN"

if [[ $run_parsimony -eq 1 || $run_nj -eq 1 ]]; then
    [[ $have_paup -eq 0 ]] && die "PAUP not found at: $PAUP_BIN"
    export LD_LIBRARY_PATH="$HOME/opt/paup-compat/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
    echo "Using PAUP executable: $PAUP_BIN"
fi

echo "===================================="
echo "Tree Building Pipeline"
echo "===================================="
echo "Tree methods: $TREE_METHODS"
echo "Alignment dir: $ALIGN_DIR"
echo "Tree dir: $TREE_DIR"
echo

# Find all trimmed NEXUS files
shopt -s nullglob
NEXUS_FILES=("$ALIGN_DIR"/*.trim.nexus)
[[ ${#NEXUS_FILES[@]} -gt 0 ]] || die "No .trim.nexus files found in $ALIGN_DIR"

echo "Found ${#NEXUS_FILES[@]} alignment(s)"
echo

# --------------------------------------------------
# MAXIMUM LIKELIHOOD (IQ-TREE)
# --------------------------------------------------

if [[ $run_ml -eq 1 ]]; then
    echo "[ML] Running Maximum Likelihood with IQ-TREE..."
    
    MODEL="${MODEL:-GTR+G}"
    THREADS="${THREADS:-AUTO}"
    BOOTSTRAP="${BOOTSTRAP:-1000}"
    ALRT="${ALRT:-1000}"
    
    method_num=1
    for NEXUS_FILE in "${NEXUS_FILES[@]}"; do
        # Extract FASTA equivalent
        TRIM_BASE=$(basename "$NEXUS_FILE" .trim.nexus)
        FASTA_FILE="$ALIGN_DIR/${TRIM_BASE}.trim.fasta"
        
        [[ -f "$FASTA_FILE" ]] || die "Missing FASTA file: $FASTA_FILE"
        
        ML_PREFIX="$TREE_DIR/${TRIM_BASE}_ml"
        
        echo "  [$method_num/${#NEXUS_FILES[@]}] Processing $TRIM_BASE..."
        
        ML_LOG="$REPORT_DIR/${TRIM_BASE}_iqtree.log"

        "$IQTREE_BIN" \
            -s "$FASTA_FILE" \
            -m "$MODEL" \
            -T "$THREADS" \
            -B "$BOOTSTRAP" \
            -alrt "$ALRT" \
            -pre "$ML_PREFIX" \
            >"$ML_LOG" 2>&1 || die "IQ-TREE failed for $TRIM_BASE. See $ML_LOG"
        
        [[ -f "${ML_PREFIX}.treefile" ]] || die "Missing ML treefile: ${ML_PREFIX}.treefile"
        cp "${ML_PREFIX}.treefile" "$TREE_DIR/${TRIM_BASE}_ml.tre"
        
        echo "    ✓ ML tree saved"
        ((method_num++))
    done
    echo
fi

# --------------------------------------------------
# PARSIMONY + NEIGHBOR JOINING (PAUP)
# --------------------------------------------------

if [[ $run_parsimony -eq 1 || $run_nj -eq 1 ]]; then
    OUTGROUP="${OUTGROUP:-Xenopus_laevis}"

    echo "[PAUP] Running phylogenetic analysis..."

    method_num=1
    for NEXUS_FILE in "${NEXUS_FILES[@]}"; do
        TRIM_BASE=$(basename "$NEXUS_FILE" .trim.nexus)

        NEXUS_ABS=$(realpath "$NEXUS_FILE")
        PARSIMONY_OUT="$TREE_DIR/${TRIM_BASE}_parsimony.tre"
        NJ_OUT="$TREE_DIR/${TRIM_BASE}_nj.tre"
        PAUP_LOG="$REPORT_DIR/${TRIM_BASE}_paup.log"

        echo "  [$method_num/${#NEXUS_FILES[@]}] Processing $TRIM_BASE..."
        echo "    NEXUS: $NEXUS_ABS"
        echo "    LOG:   $PAUP_LOG"

        # crude but useful validation: check outgroup string appears in file
        grep -Fq "$OUTGROUP" "$NEXUS_FILE" || die "Outgroup '$OUTGROUP' not found in $NEXUS_FILE"

        PAUP_CMD="execute $NEXUS_ABS;
outgroup $OUTGROUP;
set root=outgroup;"

        if [[ $run_parsimony -eq 1 ]]; then
            PAUP_CMD="${PAUP_CMD}
set criterion=parsimony;
hsearch addseq=random nreps=10 swap=tbr;
savetrees file=$PARSIMONY_OUT format=altnex brlens=yes replace=yes from=1 to=1;
cleartrees;"
        fi

        if [[ $run_nj -eq 1 ]]; then
            PAUP_CMD="${PAUP_CMD}
set criterion=distance;
dset distance=hky;
nj;
savetrees file=$NJ_OUT format=altnex brlens=yes replace=yes from=1 to=1;
cleartrees;"
        fi

        PAUP_CMD="${PAUP_CMD}
quit;"

        "$PAUP_BIN" >"$PAUP_LOG" 2>&1 <<EOF
$PAUP_CMD
EOF

        if [[ $run_parsimony -eq 1 ]]; then
            [[ -f "$PARSIMONY_OUT" ]] || die "Parsimony tree missing for $TRIM_BASE. See $PAUP_LOG"
            echo "    ✓ Parsimony tree saved"
        fi

        if [[ $run_nj -eq 1 ]]; then
            [[ -f "$NJ_OUT" ]] || die "NJ tree missing for $TRIM_BASE. See $PAUP_LOG"
            echo "    ✓ NJ tree saved"
        fi

        ((method_num++))
    done
    echo
fi

# --------------------------------------------------
# BAYESIAN (MrBayes)
# --------------------------------------------------

if [[ $run_mrbayes -eq 1 ]]; then
    [[ $have_sumt -eq 0 ]] && echo "WARNING: sumt not found; skipping external consensus" || true
    
    echo "[MrBayes] Running Bayesian phylogenetic analysis..."
    
    NGEN="${NGEN:-500000}"
    SAMPLEFREQ="${SAMPLEFREQ:-100}"
    PRINTFREQ="${PRINTFREQ:-1000}"
    DIAGNFREQ="${DIAGNFREQ:-1000}"
    BURNINFRAC="${BURNINFRAC:-0.25}"
    OUTGROUP="${OUTGROUP:-Xenopus_laevis}"
    
    method_num=1
    for NEXUS_FILE in "${NEXUS_FILES[@]}"; do
        TRIM_BASE=$(basename "$NEXUS_FILE" .trim.nexus)
        
        echo "  [$method_num/${#NEXUS_FILES[@]}] Processing $TRIM_BASE..."
        
        MB_NEXUS="$TMP_DIR/${TRIM_BASE}_mb.nex"
        MB_PREFIX="$TREE_DIR/${TRIM_BASE}_mrbayes"
        
        cp "$NEXUS_FILE" "$MB_NEXUS"
        
        cat >> "$MB_NEXUS" <<EOF

begin mrbayes;
    set autoclose=yes nowarn=yes;
    outgroup $OUTGROUP;
    lset nst=6 rates=gamma;
    prset statefreqpr=dirichlet(1,1,1,1);
    mcmcp nruns=2 nchains=4 ngen=$NGEN samplefreq=$SAMPLEFREQ printfreq=$PRINTFREQ diagnfreq=$DIAGNFREQ burninfrac=$BURNINFRAC filename=$MB_PREFIX;
    mcmc;
    sump;
    sumt contype=halfcompat relburnin=yes burninfrac=$BURNINFRAC;
end;
EOF
        
        MB_LOG="$REPORT_DIR/${TRIM_BASE}_mrbayes.log"

        "$MRBAYES_BIN" "$MB_NEXUS" >"$MB_LOG" 2>&1 || die "MrBayes failed for $TRIM_BASE. See $MB_LOG"
        
        [[ -f "$MB_PREFIX.con.tre" ]] || die "Missing MrBayes consensus: $MB_PREFIX.con.tre"
        
        cp "$MB_PREFIX.con.tre" "$TREE_DIR/${TRIM_BASE}_mrbayes.tre"
        echo "    ✓ MrBayes consensus saved"
        
        # Run external sumt if available
        if [[ $have_sumt -eq 1 ]]; then
            "$SUMT_BIN" \
                --con \
                --biplen \
                -b "${BURNINFRAC},${BURNINFRAC}" \
                --basename "$REPORT_DIR/${TRIM_BASE}_mrbayes_external" \
                "$MB_PREFIX.run1.t" \
                "$MB_PREFIX.run2.t" \
                >/dev/null 2>&1 || true
        fi
        
        ((method_num++))
    done
    echo
fi

echo "===================================="
echo "Tree building completed"
echo "Trees saved to: $TREE_DIR"
echo "===================================="
