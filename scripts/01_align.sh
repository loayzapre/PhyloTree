#!/usr/bin/env bash
set -euo pipefail

# 01_align.sh
# Creates multiple sequence alignments in:
#  - FASTA (.fasta)
#  - CLUSTAL (.aln)
# Supports: mafft, muscle, clustalw, clustalo (as comma-separated list)

IN_FASTA="${1:-data/raw/sequences.fsa}"
ALIGN_METHODS="${2:-mafft,muscle,clustalw}"
OUTDIR="${3:-data/alignments}"

mkdir -p "$OUTDIR"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$IN_FASTA" ]] || die "Input FASTA not found: $IN_FASTA"

echo "Input FASTA: $IN_FASTA"
echo "Alignment methods: $ALIGN_METHODS"
echo "Output dir : $OUTDIR"
echo

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Parse methods array
IFS=',' read -ra METHODS <<< "$ALIGN_METHODS"

# Check which tools are available and requested
run_mafft=0
run_muscle=0
run_clustalw=0

for method in "${METHODS[@]}"; do
    method=$(echo "$method" | xargs)  # trim whitespace
    case "$method" in
        mafft)   run_mafft=1 ;;
        muscle)  run_muscle=1 ;;
        clustalw|clustalo) run_clustalw=1 ;;
    esac
done

if [[ $run_mafft -eq 1 ]]; then
    need_cmd mafft || die "mafft not found"
fi

if [[ $run_muscle -eq 1 ]]; then
    need_cmd muscle || die "muscle not found"
fi

if [[ $run_clustalw -eq 1 ]]; then
    have_clustalw=0
    have_clustalo=0
    need_cmd clustalw && have_clustalw=1
    need_cmd clustalo && have_clustalo=1
    [[ $have_clustalw -eq 1 || $have_clustalo -eq 1 ]] || die "Neither clustalw nor clustalo found"
fi

method_count=0

# -------------------------
# 1) MAFFT
# -------------------------
if [[ $run_mafft -eq 1 ]]; then
    echo "[$(( ++method_count ))] Running MAFFT..."
    mafft --auto "$IN_FASTA" > "$OUTDIR/mafft.fasta"
    mafft --auto --clustalout "$IN_FASTA" > "$OUTDIR/mafft.aln"
    echo "  wrote: $OUTDIR/mafft.fasta"
    echo "  wrote: $OUTDIR/mafft.aln"
    echo
fi

# -------------------------
# 2) ClustalW / Clustal Omega
# -------------------------
if [[ $run_clustalw -eq 1 ]]; then
    if [[ $have_clustalw -eq 1 ]]; then
        echo "[$(( ++method_count ))] Running ClustalW..."

        # FASTA output
        clustalw -INFILE="$IN_FASTA" -OUTPUT=FASTA -OUTFILE="$OUTDIR/clustalw.fasta" >/dev/null 2>&1 \
            || clustalw -INFILE="$IN_FASTA" -OUTFILE="$OUTDIR/clustalw.fasta" >/dev/null 2>&1

        # CLUSTAL output (.aln)
        clustalw -INFILE="$IN_FASTA" -OUTPUT=CLUSTAL -OUTFILE="$OUTDIR/clustalw.aln" >/dev/null 2>&1 \
            || clustalw -INFILE="$IN_FASTA" -OUTFILE="$OUTDIR/clustalw.aln" >/dev/null 2>&1

        echo "  wrote: $OUTDIR/clustalw.fasta"
        echo "  wrote: $OUTDIR/clustalw.aln"

    else
        echo "[$(( ++method_count ))] Using Clustal Omega..."

        clustalo -i "$IN_FASTA" -o "$OUTDIR/clustalo.fasta" --outfmt=fasta --force >/dev/null 2>&1
        clustalo -i "$IN_FASTA" -o "$OUTDIR/clustalo.aln"   --outfmt=clu   --force >/dev/null 2>&1

        echo "  wrote: $OUTDIR/clustalo.fasta"
        echo "  wrote: $OUTDIR/clustalo.aln"
    fi
    echo
fi

# -------------------------
# 3) MUSCLE
# -------------------------
if [[ $run_muscle -eq 1 ]]; then
    echo "[$(( ++method_count ))] Running MUSCLE..."

    # Detect MUSCLE5 by presence of "-align" AND the banner "muscle 5"
    is_muscle5=0
    if muscle -h 2>&1 | grep -q -- "-align" && muscle -version 2>&1 | grep -qi "muscle 5"; then
        is_muscle5=1
    fi

    if [[ $is_muscle5 -eq 1 ]]; then
        # MUSCLE5 -> aligned FASTA, then convert to CLUSTAL
        muscle -align "$IN_FASTA" -output "$OUTDIR/muscle.fasta"

        python3 - <<PY
from Bio import AlignIO
inp  = r"$OUTDIR/muscle.fasta"
outp = r"$OUTDIR/muscle.aln"
aln = AlignIO.read(inp, "fasta")
AlignIO.write(aln, outp, "clustal")
PY

    else
        # MUSCLE3/4 -> CLUSTAL direct
        muscle -in "$IN_FASTA" -out "$OUTDIR/muscle.aln" -clw \
            || muscle -in "$IN_FASTA" -out "$OUTDIR/muscle.aln"
    fi

    # Hard check: must start with "CLUSTAL" if it's really CLUSTAL
    head -n 1 "$OUTDIR/muscle.aln" | grep -q "^CLUSTAL" \
        || die "muscle.aln is not CLUSTAL format (first line is not CLUSTAL)."

    echo "  wrote: $OUTDIR/muscle.aln"
    echo
fi

echo "Sanity checks:"
for f in "$OUTDIR"/*.fasta "$OUTDIR"/*.aln; do
    [[ -f "$f" ]] || continue
    echo "  ---- $f"
    head -n 4 "$f" | sed 's/^/  /'
done

echo
echo "[Gap filtering] Gap-column filtering using seqconverter (--remgapcols) ..."

command -v seqconverter >/dev/null 2>&1 || die "seqconverter not found (pip install seqconverter)"

# Remove columns where fraction of gaps >= this
REM_GAP_FRAC="${REM_GAP_FRAC:-0.5}"

shopt -s nullglob

for infile in "$OUTDIR"/*.fasta; do
    [[ "$infile" == *.trim.fasta ]] && continue

    base="$(basename "$infile" .fasta)"
    out_fasta="$OUTDIR/${base}.trim.fasta"
    out_aln="$OUTDIR/${base}.trim.aln"

    echo "  filtering: $base  (remgapcols >= $REM_GAP_FRAC)"

    # 1) FASTA
    seqconverter -i "$infile" \
        --informat fasta \
        --outformat fasta \
        --remgapcols "$REM_GAP_FRAC" \
        > "$out_fasta" || die "seqconverter failed on $infile (FASTA)"

    # 2) CLUSTAL
    seqconverter -i "$infile" \
        --informat fasta \
        --outformat clustal \
        --remgapcols "$REM_GAP_FRAC" \
        > "$out_aln" || die "seqconverter failed on $infile (CLUSTAL)"

    head -n 1 "$out_aln" | grep -q "^CLUSTAL" || die "$out_aln is not CLUSTAL format"
done

echo
echo "Filtered alignments created:"
ls -1 "$OUTDIR"/*.trim.* 2>/dev/null || echo "  (none)"