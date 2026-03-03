## Software requirements

1. Create the Conda environment
It is recommended to use conda or mamba to create an isolated environment.
    conda create -n whale_phylo python=3.11
    conda activate whale_phylo

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