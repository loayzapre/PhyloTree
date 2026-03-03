#!/usr/bin/env bash
set -euo pipefail

# 01_align.sh
# Creates 3 multiple-sequence alignments in:
#  - FASTA (.fasta)
#  - CLUSTAL (.aln)

IN_FASTA="${1:-data/raw/sequences.fsa}"
OUTDIR="${2:-data/alignments}"

mkdir -p "$OUTDIR"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$IN_FASTA" ]] || die "Input FASTA not found: $IN_FASTA"

echo "Input FASTA: $IN_FASTA"
echo "Output dir : $OUTDIR"
echo

need_cmd() { command -v "$1" >/dev/null 2>&1; }

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
mafft --auto --clustalout "$IN_FASTA" > "$OUTDIR/mafft.aln"
echo "  wrote: $OUTDIR/mafft.fasta"
echo "  wrote: $OUTDIR/mafft.aln"
echo

# -------------------------
# 2) ClustalW / Clustal Omega
# -------------------------
if [[ $have_clustalw -eq 1 ]]; then
  echo "[2/3] Running ClustalW..."

  # FASTA output
  clustalw -INFILE="$IN_FASTA" -OUTPUT=FASTA -OUTFILE="$OUTDIR/clustalw.fasta" >/dev/null 2>&1 \
    || clustalw -INFILE="$IN_FASTA" -OUTFILE="$OUTDIR/clustalw.fasta" >/dev/null 2>&1

  # CLUSTAL output (.aln)
  # Many clustalw builds default to CLUSTAL; force it explicitly:
  clustalw -INFILE="$IN_FASTA" -OUTPUT=CLUSTAL -OUTFILE="$OUTDIR/clustalw.aln" >/dev/null 2>&1 \
    || clustalw -INFILE="$IN_FASTA" -OUTFILE="$OUTDIR/clustalw.aln" >/dev/null 2>&1

  echo "  wrote: $OUTDIR/clustalw.fasta"
  echo "  wrote: $OUTDIR/clustalw.aln"

else
  echo "[2/3] Using Clustal Omega..."

  clustalo -i "$IN_FASTA" -o "$OUTDIR/clustalo.fasta" --outfmt=fasta --force >/dev/null 2>&1
  clustalo -i "$IN_FASTA" -o "$OUTDIR/clustalo.aln"   --outfmt=clu   --force >/dev/null 2>&1

  echo "  wrote: $OUTDIR/clustalo.fasta"
  echo "  wrote: $OUTDIR/clustalo.aln"
fi
echo

echo "[3/3] Running MUSCLE..."

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

echo "Sanity checks:"
for f in "$OUTDIR"/*.fasta "$OUTDIR"/*.aln; do
  [[ -f "$f" ]] || continue
  echo "  ---- $f"
  head -n 4 "$f" | sed 's/^/  /'
done

echo
echo "Done."