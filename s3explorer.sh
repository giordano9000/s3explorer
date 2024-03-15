#!/bin/bash

PROFILE="olsatemp"
KEY_GENERATOR_PATH="./olsa-generate-aws-temp-keys.sh"
DOWNLOAD_PATH="$HOME/Desktop"

# Color variables
ORANGE='\033[0;33m'
FLUORESCENT='\033[1;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if PROFILE is "olsatemp" and execute KEY_GENERATOR_PATH script
generate_temp_keys(){
    if [ "$PROFILE" = "olsatemp" ]; then
        bash "$KEY_GENERATOR_PATH"
    else
        echo "PROFILE is not olsatemp. Proceeding with the rest of the script..."
    fi
}

list_bucket_contents() {
    local s3Path=$(echo "$1$2" | sed 's#//#/#g')
    local contents

    contents=$(aws s3 --profile $PROFILE ls "s3://$s3Path")
    echo "$contents"
}

# Function to retrieve AWS credentials
get_aws_credentials() {
    local profile="$PROFILE"
    local aws_access_key
    local aws_secret_key

    aws_access_key=$(aws configure get aws_access_key_id --profile "$profile")
    aws_secret_key=$(aws configure get aws_secret_access_key --profile "$profile")

    echo -e "${ORANGE}AWS credentials retrieved for profile $profile.${NC}"
    export AWS_ACCESS_KEY_ID="$aws_access_key"
    export AWS_SECRET_ACCESS_KEY="$aws_secret_key"
}

# Remove slash from a string
remove_slash() {
    local string="$1"
    echo $(echo "$string" | sed 's/\///g')
}

# Function to prompt user to select directory or file
select_item() {
    local prefix="$1"
    local file_list
    local choice

    file_list=$(list_bucket_contents "$bucket" "$prefix")
    options=($(echo "$file_list" | awk '/PRE/ {print "d:" $NF} !/PRE/ {print "f:" $NF}'))
    PS3=$'\n'"Select an item: "
    options=("p:parent_dir" "${options[@]}")  # Adding Parent directory as the first option
    select choice in "${options[@]}"; do
        if [ -n "$choice" ]; then
            item_type=${choice:0:1}
            item_name=${choice:2}
            item_name=$(remove_slash "$item_name")
            case $item_type in
                "d")
                    if [ "$item_name" == ".." ]; then
                        list_directories "$(dirname "$prefix")/" # Go to the parent directory
                    else
                        list_directories "$prefix/$item_name/"
                    fi
                    break
                    ;;
                "f")
                    download_file "$prefix/$item_name"  # Modified to download the file
                    list_directories "$prefix/"
		            break
                    ;;
                "p")
                    list_directories "$(dirname "$prefix")/" # Go to the parent directory
                    break
                    ;;
                *) echo "Invalid option";;
            esac
        else
            echo "Invalid selection. Please choose again."
        fi
    done
}

# Function to download a file
download_file() {
    local bucket=$(echo "$bucket" | sed 's#//#/#g')
    local filename=$(echo "$1" | sed 's#//#/#g')
    local s3Path="$bucket$filename"
    s3Path=$(echo "$s3Path" | sed 's#//#/#g')
    echo -e "${ORANGE}Downloading file: $s3Path${NC}"
    aws s3 --profile $PROFILE cp "s3://$s3Path" "$DOWNLOAD_PATH/$filename"
}

# Function to list directories
list_directories() {
    local prefix2="$(echo "$1" | sed 's#//#/#g')"
    local contents

    contents=$(list_bucket_contents "$bucket" "$prefix2")

    select_item "$prefix2"
}

# Main function
main() {
    local bucket="amex-bucket"
    local contents

    echo -e "\n\n${FLUORESCENT}${BOLD}S3Explorer by G.Verrelli v. 3.0.12${NC}"
    generate_temp_keys
    echo -e "\n${ORANGE}Retrieving AWS credentials from ~/.aws/credentials...${NC}"
    get_aws_credentials

    list_directories ""
}

main "$@"
