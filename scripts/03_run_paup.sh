#!/usr/bin/bash

# 1. Configuration
# List your Nexus files here
INPUT_FILES=("clustalw.nexus" "mafft.nexus" "muscle.nexus")

# Define the Outgroup name (IMPORTANT: Must match the name inside your Nexus file)
OUTGROUP_NAME=("MW417983.1" "PX623998.1")

# 2. Loop through files
for FILE in "${INPUT_FILES[@]}"
do
    BASE="${FILE%.*}"
    
    echo "--------------------------------------------------"
    echo "Processing $FILE..."
    echo "--------------------------------------------------"

    # Run PAUP*
    # We send the commands directly to the paup executable
    paup <<EOF
    # Load the alignment
    execute $FILE;

    # Define the outgroup and root the tree
    outgroup $OUTGROUP_NAME;
    set root=outgroup;

    # --- TASK 1: PARSIMONY TREE ---
    set criterion=parsimony;
    # Heuristic search with TBR (Tree Bisection and Reconnection)
    # addseq=random makes the search more robust
    hsearch addseq=random nreps=10 swap=tbr;
    # Save the parsimony tree
    savetrees file=${BASE}_parsimony.tre format=altnex brlens=yes replace=yes;

    # --- TASK 2: NEIGHBOUR JOINING TREE ---
    set criterion=distance;
    # Set distance correction to HKY
    dset distance=hky;
    # Run NJ algorithm
    nj;
    # Save the NJ tree
    savetrees file=${BASE}_nj.tre format=altnex brlens=yes replace=yes;

    # Exit PAUP
    quit;
EOF

done

echo "Done! You now have 6 tree files (.tre)"