# Author: Tong Wu 
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
    mkdir -p "$NEW_FOLDER_PATH"

    # Path to the 125construct directory
CONSTRUCT_DIR="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL"
NEW_CONSTRUCT_DIR="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL$VOLTAGE_NUMBER"

# Create the new directory if it doesn't exist
mkdir -p "$NEW_CONSTRUCT_DIR"

    # Check if NEW_CONSTRUCT_DIR already exists
    if [ -d "$NEW_CONSTRUCT_DIR" ] && [ "$(ls -A $NEW_CONSTRUCT_DIR)" ]; then
       rm -rf "$NEW_CONSTRUCT_DIR/*"
    fi
    cp -r "$CONSTRUCT_DIR/"* "$NEW_CONSTRUCT_DIR/"

# Continue with the rest of your script
cp "$VOLTAGE_FILE" "$BASE_LOCAL_PATH/$VOLTAGE_NUMBER/voltage.txt"
cp "$BASE_LOCAL_PATH/clock.txt" "$BASE_LOCAL_PATH/$VOLTAGE_NUMBER/clock.txt"
echo "Changing the asap voltage"

# Apply the sed command to modify the new file
sed -i "22s/adk_name = 'asap7'/adk_name = 'asap7$VOLTAGE_NUMBER'/" "$NEW_CONSTRUCT_DIR/construct.py"

    # Step 3: Copy the script.sh into the newly created folder (xxx)
    NEW_SCRIPT_PATH="$NEW_FOLDER_PATH/script.sh"
    cp "$LOCAL_SCRIPT_PATH" "$NEW_SCRIPT_PATH"
    echo "change the script voltage" 
    # Modify the script to set VOLTAGE to the current voltage number
    sed -i "1s/^VOLTAGE_NUMBER=\".*\"/VOLTAGE_NUMBER=\"$VOLTAGE_NUMBER\"/" "$NEW_SCRIPT_PATH"

    # Step 4: Change into the newly created folder (xxx)
    cd "$NEW_FOLDER_PATH" || { echo "Failed to change directory to $NEW_FOLDER_PATH"; exit 1; }

    # Step 5: Create a 'build' folder inside the (xxx) folder
    mkdir -p "build"

    # Step 6: Copy the ASAP7 folder to asap7xxxx
    ASAP7_NEW_PATH="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/adks/asap7$VOLTAGE_NUMBER"

    # Check if the destination directory already exists
    if [ ! -d "$ASAP7_NEW_PATH" ]; then
        # If the directory does not exist, copy the ASAP7 folder
        echo "starting to copy"
	cp -r "$ASAP7_BASE_PATH" "$ASAP7_NEW_PATH"
        echo "Copied ASAP7 folder to $ASAP7_NEW_PATH."
 # Updating the LIBRARY_FILE with the voltage number
        LIBRARY_FILE="$ASAP7_NEW_PATH/view-standard/stdcells.lib"
       time sed -i -e "47s/voltage_map (VDD, 0.6);/voltage_map (VDD, $VOLTAGE_NUMBER);/" \
               -e "116s/vih : 0.6;/vih : $VOLTAGE_NUMBER;/" \
               -e "118s/vimax : 0.6;/vimax : $VOLTAGE_NUMBER;/" \
               -e "122s/voh : 0.6;/voh : $VOLTAGE_NUMBER;/" \
               -e "124s/vomax : 0.6;/vomax : $VOLTAGE_NUMBER;/" \
               -e "70s/voltage : 0.6;/voltage : $VOLTAGE_NUMBER;/" \
               -e "59s/nom_voltage : 0.7;/nom_voltage : $VOLTAGE_NUMBER;/" "$LIBRARY_FILE"
 
    fi 
       
    echo "SSH into $MACHINE" 
    # Step 7: Run the copied script on the remote machine with sourcing .bashrc
    ssh "tongwu2@$MACHINE" "source ~/.bashrc; cd $BASE_LOCAL_PATH; : > $BASE_LOCAL_PATH/script_output$VOLTAGE_NUMBER.log; cd ./$VOLTAGE_NUMBER; bash ./script.sh > $BASE_LOCAL_PATH/script_output$VOLTAGE_NUMBER.log 2>&1; echo \$?" &

done

echo "Running in the background"

