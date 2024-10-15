#!/bin/bash
# Author: Tong Wu
# Description: Configure the mflowgen run for a shmoo plot generation
# Date: Oct 14th 2025

# Define the user and the range of machines
USER="tongwu2"
MACHINE_PREFIX="ece"
MACHINE_SUFFIX=("001" "002" "003" "004" "005" "006" "007" "008" "009" "010" "011" "012" "013" "014" "015" "016" "017" "018" "019")
# Base local directory where operations will be performed
BASE_LOCAL_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/build"

# Voltage file location
VOLTAGE_FILE="$BASE_LOCAL_PATH/voltage.txt"

# Local script file to copy
LOCAL_SCRIPT_PATH="$BASE_LOCAL_PATH/script.sh"

# Base path for the ASAP7 directory
ASAP7_BASE_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/adks/asap7"
# Setup file for rtk-130
SETUP_FILE="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/steps/cadence-innovus-flowsetup/setup.tcl"
# Array to hold the paths of the ASAP7 directories for cleanup
ASAP7_DIRS=()

# Step 1: Check if voltage.txt exists and read its lines
if [[ ! -f "$VOLTAGE_FILE" ]]; then
    echo "Error: voltage.txt not found at $VOLTAGE_FILE"
    exit 1
fi

# Read the voltage numbers into an array
mapfile -t VOLTAGE_NUMBERS < "$VOLTAGE_FILE"

i = 1
node = 45 
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
    
    cd $BASE_LOCAL_PATH
    # Get the voltage number for the current iteration
    VOLTAGE_NUMBER="${VOLTAGE_NUMBERS[$((10#$i - 1))]}"

    if [[ -z "$VOLTAGE_NUMBER" ]]; then
        echo "Error: voltage number is empty for machine $MACHINE"
        continue
    fi

    echo "Processing $MACHINE with voltage number: $VOLTAGE_NUMBER" 

    # Step 2: Create a folder with the voltage number as the folder name (xxx)
    NEW_FOLDER_PATH="$BASE_LOCAL_PATH/$VOLTAGE_NUMBER"
    mkdir -p "$NEW_FOLDER_PATH"

    # Path to the 125construct directory
    CONSTRUCT_DIR="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL"
    NEW_CONSTRUCT_DIR="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL$VOLTAGE_NUMBER"

    # Check if NEW_CONSTRUCT_DIR already exists
    if [ -d "$NEW_CONSTRUCT_DIR" ] && [ "$(ls -A $NEW_CONSTRUCT_DIR)" ]; then
        echo "$NEW_CONSTRUCT_DIR already exists, skipping copy."
    else
        # If it doesn't exist, copy the directory
        echo "Copying $CONSTRUCT_DIR to $NEW_CONSTRUCT_DIR..."
        mkdir -p "$NEW_CONSTRUCT_DIR"
        cp -r "$CONSTRUCT_DIR/"* "$NEW_CONSTRUCT_DIR/"
    fi

    # Modify line 22 of construct.py based on the node value
    if [ "$node" -eq 45 ]; then
        sed -i "22s/adk_name = '.*'/adk_name = 'freepdk-45nm$VOLTAGE_NUMBER'/" "$NEW_CONSTRUCT_DIR/construct.py"
    else
        sed -i "22s/adk_name = '.*'/adk_name = 'asap7$VOLTAGE_NUMBER'/" "$NEW_CONSTRUCT_DIR/construct.py"
    fi

    # Modify line 22 of construct.py based on the node value
    if [ "$node" -eq 45 ]; then
        sed -i "22s/adk_name = '.*'/adk_name = 'freepdk-45nm$VOLTAGE_NUMBER'/" "$NEW_CONSTRUCT_DIR/construct.py"
    else
        sed -i "22s/adk_name = '.*'/adk_name = 'asap7$VOLTAGE_NUMBER'/" "$NEW_CONSTRUCT_DIR/construct.py"
    fi
    
    # Continue with the rest of your script
    cp "$VOLTAGE_FILE" "$BASE_LOCAL_PATH/$VOLTAGE_NUMBER/voltage.txt"
    cp "$BASE_LOCAL_PATH/clock.txt" "$BASE_LOCAL_PATH/$VOLTAGE_NUMBER/clock.txt"

    # Copy the script.sh into the newly created folder
    NEW_SCRIPT_PATH="$NEW_FOLDER_PATH/script.sh"
    cp "$LOCAL_SCRIPT_PATH" "$NEW_SCRIPT_PATH"
    echo "change the script voltage" 
    # Modify the script to set VOLTAGE to the current voltage number
    sed -i "1s/^VOLTAGE_NUMBER=\".*\"/VOLTAGE_NUMBER=\"$VOLTAGE_NUMBER\"/" "$NEW_SCRIPT_PATH"

    # Change into the newly created folder (xxx)
    cd "$NEW_FOLDER_PATH" || { echo "Failed to change directory to $NEW_FOLDER_PATH"; exit 1; }

    # Create a 'build' folder inside the (xxx) folder
    mkdir -p "build"

    # Copy the ASAP7 folder to asap7xxxx
    ASAP7_NEW_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/adks/asap7$VOLTAGE_NUMBER"

    # Check if node is equal to 7 or 45
    if [ "$node" -eq 7 ]; then
        # Check if the destination directory already exists for ASAP7
        if [ ! -d "$ASAP7_NEW_PATH" ]; then
            # If the directory does not exist, copy the ASAP7 folder
            echo "Starting to copy ASAP7 to $ASAP7_NEW_PATH"
            time cp -r "$ASAP7_BASE_PATH" "$ASAP7_NEW_PATH"
            echo "Copied ASAP7 folder to $ASAP7_NEW_PATH."

            # Updating the LIBRARY_FILE with the voltage number
            LIBRARY_FILE="$ASAP7_NEW_PATH/view-standard/stdcells.lib"
            echo "Updating LIBRARY_FILE at $LIBRARY_FILE"
            
            time sed -i -e "47s/voltage_map (VDD, 0.6);/voltage_map (VDD, $VOLTAGE_NUMBER);/" \
                -e "116s/vih : 0.6;/vih : $VOLTAGE_NUMBER;/" \
                -e "118s/vimax : 0.6;/vimax : $VOLTAGE_NUMBER;/" \
                -e "122s/voh : 0.6;/voh : $VOLTAGE_NUMBER;/" \
                -e "124s/vomax : 0.6;/vomax : $VOLTAGE_NUMBER;/" \
                -e "70s/voltage : 0.6;/voltage : $VOLTAGE_NUMBER;/" \
                -e "59s/nom_voltage : 0.7;/nom_voltage : $VOLTAGE_NUMBER;/" "$LIBRARY_FILE"
        fi 
        sed -i "425s|.*|set vars(gds_layer_map)                       \$vars(adk_dir)/rtk-stream-out-130.map|" "$SETUP_FILE"
    elif [ "$node" -eq 45 ]; then
        sed -i "425s|.*|set vars(gds_layer_map)                       \$vars(adk_dir)/rtk-stream-out-130.map|" "$SETUP_FILE"
        # Define paths for freepdk
        FREEPDK_BASE_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/adks/freepdk-45nm"
        FREEPDK_NEW_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/adks/freepdk-45nm$VOLTAGE_NUMBER"
        # Check if the destination directory already exists for freepdk
        if [ ! -d "$FREEPDK_NEW_PATH" ]; then
            # If the directory does not exist, copy the freepdk folder
            echo "Starting to copy freepdk-45nm to $FREEPDK_NEW_PATH"
            time cp -r "$FREEPDK_BASE_PATH" "$FREEPDK_NEW_PATH"
            echo "Copied freepdk-45nm folder to $FREEPDK_NEW_PATH."

            # Updating the LIBRARY_FILE with the voltage number
            LIBRARY_FILE="$FREEPDK_NEW_PATH/view-standard/stdcells.lib"
            echo "Updating LIBRARY_FILE at $LIBRARY_FILE"
            
            time sed -i -e "61s/nom_voltage                           : 0.4;/nom_voltage                           : $VOLTAGE_NUMBER;/" \
                -e "63s/voltage_map (VDD, 0.4);/voltage_map (VDD, $VOLTAGE_NUMBER);/" \
                -e "70s/voltage             : 0.4;/voltage             : $VOLTAGE_NUMBER;/" "$LIBRARY_FILE"
        fi 
    fi

       
    echo "SSH into $MACHINE" 
    # Step 7: Run the copied script on the remote machine with sourcing .bashrc
    ssh "tongwu2@$MACHINE" "source ~/.bashrc; cd $BASE_LOCAL_PATH; : > $BASE_LOCAL_PATH/script_output$VOLTAGE_NUMBER.log; cd ./$VOLTAGE_NUMBER; bash ./script.sh > $BASE_LOCAL_PATH/script_output$VOLTAGE_NUMBER.log 2>&1; echo \$?" &
    ((i++))

done

echo "Running in the background"

