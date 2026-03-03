#!/usr/bin/env bash
set -euo pipefail

# 01_align.sh
# Creates 3 multiple-sequence alignments (FASTA format)

IN_FASTA="${1:-data/raw/sequences.fsa}"
OUTDIR="${2:-data/alignments}"

mkdir -p "$OUTDIR"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$IN_FASTA" ]] || die "Input FASTA not found: $IN_FASTA"

echo "Input FASTA: $IN_FASTA"
echo "Output dir : $OUTDIR"
echo

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_cmd mafft   || die "mafft not found"
need_cmd muscle  || die "muscle not found"

have_clustalw=0
have_clustalo=0

need_cmd clustalw && have_clustalw=1
need_cmd clustalo && have_clustalo=1

[[ $have_clustalw -eq 1 || $have_clustalo -eq 1 ]] || die "Neither clustalw nor clustalo found"

# -------------------------
# 1) MAFFT
# -------------------------
echo "[1/3] Running MAFFT..."
mafft --auto "$IN_FASTA" > "$OUTDIR/mafft.fasta"
echo "  wrote: $OUTDIR/mafft.fasta"
echo

# -------------------------
# 2) ClustalW / Clustal Omega
# -------------------------
if [[ $have_clustalw -eq 1 ]]; then
  echo "[2/3] Running ClustalW..."

  clustalw -INFILE="$IN_FASTA" -OUTPUT=FASTA -OUTFILE="$OUTDIR/clustalw.fasta" >/dev/null 2>&1 \
  || clustalw -INFILE="$IN_FASTA" -OUTFILE="$OUTDIR/clustalw.fasta" >/dev/null 2>&1

  echo "  wrote: $OUTDIR/clustalw.fasta"

else
  echo "[2/3] Using Clustal Omega..."

  clustalo -i "$IN_FASTA" -o "$OUTDIR/clustalo.fasta" --outfmt=fasta --force >/dev/null 2>&1

  echo "  wrote: $OUTDIR/clustalo.fasta"
fi
echo

# -------------------------
# 3) MUSCLE
# -------------------------
echo "[3/3] Running MUSCLE..."

if muscle -h 2>&1 | grep -qiE "align|output"; then
    muscle -align "$IN_FASTA" -output "$OUTDIR/muscle.fasta"
else
    muscle -in "$IN_FASTA" -out "$OUTDIR/muscle.fasta"
fi

echo "  wrote: $OUTDIR/muscle.fasta"
echo

echo "Sanity checks:"
for f in "$OUTDIR"/*.fasta; do
  head -n 2 "$f" | sed 's/^/  /'
done

echo
echo "Done."