#!/bin/bash

# Base local directory where operations will be performed
BASE_LOCAL_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/build"

# Voltage file location
VOLTAGE_FILE="$BASE_LOCAL_PATH/voltage.txt"

# Local script file to copy
LOCAL_SCRIPT_PATH="$BASE_LOCAL_PATH/script.sh"

# Base path for the ASAP7 directory
ASAP7_BASE_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/adks/asap7"

# Array to hold the paths of the ASAP7 directories for cleanup
ASAP7_DIRS=()

# Step 1: Check if voltage.txt exists and read its lines
if [[ ! -f "$VOLTAGE_FILE" ]]; then
    echo "Error: voltage.txt not found at $VOLTAGE_FILE"
    exit 1
fi

# Read the voltage numbers into an array
mapfile -t VOLTAGE_NUMBERS < "$VOLTAGE_FILE"

# Loop over the machine numbers (1 to 19) and construct machine hostnames
for i in $(seq -w 1 19); do
    if [ "$i" -lt 10 ]; then
        MACHINE="ece0$i.ece.local.cmu.edu"  # For machines ece001 to ece009
    else
        MACHINE="ece0$i.ece.local.cmu.edu"   # For machines ece010 to ece019
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
    #echo "Creating folder $NEW_FOLDER_PATH..."
    mkdir -p "$NEW_FOLDER_PATH"

    # Path to the 125construct directory
    CONSTRUCT_DIR="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL"
    NEW_CONSTRUCT_DIR="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL$VOLTAGE_NUMBER"
    cp -r "$SOURCE_DIR" "$DEST_DIR"

    cp "$VOLTAGE_FILE" "$BASE_LOCAL_PATH/$VOLTAGE_NUMBER/voltage.txt"
    cp "$BASE_LOCAL_PATH/clock.txt" "$BASE_LOCAL_PATH/$VOLTAGE_NUMBER/clock.txt"
    # Apply the sed command to modify the new file
    sed -i "22s/adk_name = 'asap7'/adk_name = 'asap7$VOLTAGE_NUMBER'/" "$NEW_CONSTRUCT_DIR/construct.py" 

    # Step 3: Copy the script.sh into the newly created folder (xxx)
    NEW_SCRIPT_PATH="$NEW_FOLDER_PATH/script.sh"
    #echo "Copying script.sh to $NEW_SCRIPT_PATH..."
    cp "$LOCAL_SCRIPT_PATH" "$NEW_SCRIPT_PATH"
    
    #echo "Modifying $NEW_SCRIPT_PATH to set VOLTAGE to $VOLTAGE_NUMBER..."
    sed -i "1s/^VOLTAGE_NUMBER=\".*\"/VOLTAGE_NUMBER=\"$VOLTAGE_NUMBER\"/" "$NEW_SCRIPT_PATH"
    # Step 4: Change into the newly created folder (xxx)
    #echo "Changing directory to $NEW_FOLDER_PATH..."
    cd "$NEW_FOLDER_PATH" || { echo "Failed to change directory to $NEW_FOLDER_PATH"; exit 1; }

    # Step 5: Create a 'build' folder inside the (xxx) folder
    #echo "Creating 'build' folder inside $NEW_FOLDER_PATH..."
    mkdir -p "build"

    # Step 5: Copy the asap7 folder to asap7xxxx
    ASAP7_NEW_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/adks/asap7$VOLTAGE_NUMBER"
    # echo "Copying ASAP7 folder to $ASAP7_NEW_PATH..."
    # Check if the destination directory already exists
    if [ ! -d "$ASAP7_NEW_PATH" ]; then
    	# If the directory does not exist, copy the ASAP7 folder
    	cp -r "$ASAP7_BASE_PATH" "$ASAP7_NEW_PATH"
    	echo "Copied ASAP7 folder to $ASAP7_NEW_PATH."
  
    #echo "Updating $LIBRARY_FILE with VOLTAGE_NUMBER..."
    LIBRARY_FILE="$ASAP7_NEW_PATH/view-standard/stdcells.lib"
  sed -i -e "47s/voltage_map (VDD, 0.6);/voltage_map (VDD, $VOLTAGE_NUMBER);/" \
           -e "116s/vih : 0.6;/vih : $VOLTAGE_NUMBER;/" \
           -e "118s/vimax : 0.6;/vimax : $VOLTAGE_NUMBER;/" \
           -e "122s/voh : 0.6;/voh : $VOLTAGE_NUMBER;/" \
           -e "124s/vomax : 0.6;/vomax : $VOLTAGE_NUMBER;/" \
           -e "70s/voltage : 0.6;/voltage : $VOLTAGE_NUMBER;/" \
           -e "59s/nom_voltage : 0.7;/nom_voltage : $VOLTAGE_NUMBER;/" "$LIBRARY_FILE"

    else
    	# If the directory exists, print a message
    	echo "Directory $ASAP7_NEW_PATH already exists. Skipping copy."
    fi



    # Run the copied script on the remote machine with sourcing .bashrc

     ssh "tongwu2@$MACHINE" "source ~/.bashrc; cd $BASE_LOCAL_PATH; : > $BASE_LOCAL_PATH/script_output$VOLTAGE_NUMBER.log; cd ./$VOLTAGE_NUMBER; bash ./script.sh  > $BASE_LOCAL_PATH/script_output$VOLTAGE_NUMBER.log 2>&1; echo \$?" &
done


echo "running in background"

