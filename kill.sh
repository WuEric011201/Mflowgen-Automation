#!/bin/bash
# Author: Tong Wu
# Description: Kill all the processes
# Date: Oct 14th 2025

# Define the user and the range of machines
USER="tongwu2"
MACHINE_PREFIX="ece"
MACHINE_SUFFIX=("001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019")

# Loop over each machine
for SUFFIX in "${MACHINE_SUFFIX[@]}"; do
    MACHINE="$MACHINE_PREFIX$SUFFIX.ece.local.cmu.edu"
    
    echo "Connecting to $MACHINE to kill processes..."

    # Kill all processes for the specified user on the remote machine
    ssh "$USER@$MACHINE" "pkill -u $USER"
    
    wait
    # Optionally, you can add error checking here
    if [ $? -eq 0 ]; then
        echo "Successfully killed processes on $MACHINE."
    else
        echo "Failed to kill processes on $MACHINE."
    fi
done
