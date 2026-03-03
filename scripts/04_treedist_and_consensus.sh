#!/usr/bin/bash

# Configuration: Names of the 6 trees generated previously
TREES=(
    "clustalw_parsimony.tre" "clustalw_nj.tre"
    "muscle_parsimony.tre" "mafft_nj.tre"
    "mafft_parsimony.tre" "muscle_nj.tre"
)

# We use any one of your NEXUS data files to define the taxa list for PAUP
DATA_FILE="alignment1.nexus"

echo "Starting Tree Comparison Analysis..."

paup <<EOF
    # Load the taxa definitions
    execute $DATA_FILE;

    # Load all 6 trees into memory (mode=7 appends them)
    gettrees file=${TREES[0]} mode=7;
    gettrees file=${TREES[1]} mode=7;
    gettrees file=${TREES[2]} mode=7;
    gettrees file=${TREES[3]} mode=7;
    gettrees file=${TREES[4]} mode=7;
    gettrees file=${TREES[5]} mode=7;

    # 1. QUANTIFY DIFFERENCES (Tree Distances)
    # This generates a symmetric distance matrix
    treedist method=symmetric;

    # 2. FIND AGREEMENT (Consensus Tree)
    # majrule=yes shows clades appearing in >50% of trees
    # showtreedist=yes adds support values (percentages) to the branches
    contree all / majrule=yes showtreedist=yes;

    # Save the consensus tree to a file
    savetrees file=final_consensus_tree.tre format=altnex replace=yes;

    quit;
EOF

echo "Analysis complete. Check the terminal output for the distance matrix and consensus tree."