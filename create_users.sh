#!/bin/bash

####################################################################
# Script to create users and groups based on a text file input
# Author: [Dorcas Adebayo]
# Date: [06-July-2024]
# Usage: sudo ./create_users.sh dev.txt
####################################################################

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Ensure an argument is provided
if [[ -z $1 ]]; then
    echo "Usage: $0 <name-of-text.file>"
    exit 1
fi

# Define file paths
TEXT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure the text file exists
if [[ ! -f $TEXT_FILE ]]; then
    echo "Text file not found: $TEXT_FILE" | tee -a $LOG_FILE
    exit 1
fi

# Create /var/secure directory if it does not exist
mkdir -p /var/secure

# Clear the password file
> $PASSWORD_FILE

# Set permissions for the password file
chmod 600 $PASSWORD_FILE

# Function to generate a random password
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%&*' < /dev/urandom | head -c 12
}

# Read the text file line by line
while IFS=';' read -r user groups; do
    # Remove leading and trailing whitespace
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs)

    if id "$user" &>/dev/null; then
        echo "User $user already exists, skipping." | tee -a $LOG_FILE
        continue
    fi

    # Create the user's personal group
    if ! getent group "$user" > /dev/null; then
        groupadd "$user"
        echo "Group $user created." | tee -a $LOG_FILE
    fi

    # Create the user with their personal group
    useradd -m -g "$user" -s /bin/bash "$user"
    if [[ $? -ne 0 ]]; then
        echo "Failed to create user $user." | tee -a $LOG_FILE
        continue
    fi
    echo "User $user created." | tee -a $LOG_FILE

    # Set the user's groups
    if [[ -n "$groups" ]]; then
        IFS=',' read -ra group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            group=$(echo "$group" | xargs)
            if ! getent group "$group" > /dev/null; then
                groupadd "$group"
                echo "Group $group created." | tee -a $LOG_FILE
            fi
            usermod -aG "$group" "$user"
            echo "User $user added to group $group." | tee -a $LOG_FILE
        done
    fi

    # Generate a random password for the user
    password=$(generate_password)
    echo "$user:$password" | chpasswd
    if [[ $? -ne 0 ]]; then
        echo "Failed to set password for user $user." | tee -a $LOG_FILE
        continue
    fi
    echo "Password set for user $user." | tee -a $LOG_FILE

    # Store the password securely
    echo "$user,$password" >> $PASSWORD_FILE

    # Set permissions for the home directory
    chmod 700 "/home/$user"
    chown "$user:$user" "/home/$user"
    echo "Permissions set for user $user's home directory." | tee -a $LOG_FILE

done < "$TEXT_FILE"

echo "User creation process completed." | tee -a $LOG_FILE
