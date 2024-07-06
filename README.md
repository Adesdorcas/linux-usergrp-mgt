# Linux User Creation Bash Script

This is a bash script called create_users.sh that reads a text file containing the employee’s usernames and group names, where each line is formatted as user;groups.

The script create users and groups as specified, set up home directories with appropriate permissions and ownership, generate random passwords for the users, and log all actions to /var/log/user_management.log. Additionally, stores the generated passwords securely in /var/secure/user_passwords.csv.