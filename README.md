## Software requirements

    project/
    ├─ data/
    │  ├─ raw/
    │  │  └─ whales.fasta                 # input sequences (FASTA)
    │  ├─ alignments/
    │  │  ├─ mafft.aln                    # CLUSTAL format
    │  │  ├─ clustalw.aln                 # CLUSTAL format
    │  │  ├─ muscle.aln                   # CLUSTAL format (or any 3rd method)
    │  │  ├─ mafft.nex                    # NEXUS for PAUP
    │  │  ├─ clustalw.nex
    │  │  └─ muscle.nex
    │  ├─ trees/
    │  │  ├─ mafft_pars.tre               # Newick (or NEXUS tree block)
    │  │  ├─ mafft_nj.tre
    │  │  ├─ clustalw_pars.tre
    │  │  ├─ clustalw_nj.tre
    │  │  ├─ muscle_pars.tre
    │  │  └─ muscle_nj.tre
    │  └─ reports/
    │     ├─ treedist.tsv                 # pairwise distances table
    │     ├─ consensus.tre                # consensus tree (Newick)
    │     └─ paup_commands.log            # optional
    ├─ scripts/
    │  ├─ 01_align.sh
    │  ├─ 02_convert_to_nexus.py
    │  ├─ 03_paup_build_trees.nex         # PAUP command script template
    │  ├─ 03_run_paup.sh
    │  ├─ 04_treedist_and_consensus.nex   # PAUP script for treedist+consensus
    │  ├─ 05_export_figtrees.md           # instructions checklist (manual step)
    │  └─ run_all.sh
    └─ README.md


1. Create the Conda environment
It is recommended to use conda or mamba to create an isolated environment.
    conda env create -f environment.yml
    conda activate phylo

Then
    pip install -r requirements.txt

External tools (must be installed separately):

    MAFFT
    ClustalW or Clustal Omega
    MUSCLE
    PAUP*
    FigTree

These tools must be available in the system PATH so they can be called
from the scripts.

### PAUP configuration (important)
The script 03_run_paup.sh requires the PAUP executable path.

If paup is available in your PATH, the script will detect it automatically.

Otherwise you must specify the executable manually when running the script.

## How to run
Ajust outgroup name in 03 and 04 script, and then 
    nohup bash run_all.sh > pipeline.log 2>&1 &