#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

# Build the project.
# Really important: If you use a theme add quotation marks nasty errors when creating your pages.
./hugo -t "hugo-coder"

# Go To Public folder
cd public

# Add changes to git.
git add .

# Read a commit message in
read -p "Please enter a commit message: " msg

# Commit changes.
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Finally: push source and build repos.
git push origin master

# From here on your changes to github pages are live so that you can view them.