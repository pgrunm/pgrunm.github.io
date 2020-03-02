---
title: "Building my new blog: Part 2"
date: 2020-02-13T14:31:31+01:00
draft: false
tags: [git, submodule, continuous deployment, bash]
---

In the last post I wrote about my considerations about what software to use for my blog, where to host it and how to set it up. This post contains some more techinical details like the git structure and the deployment process. So then let's dive in.

## The git structure

The hugo projects mentions in their documentation to use [a git submodule](https://gohugo.io/getting-started/quick-start/) for the theme. [Git](https://git-scm.com/book/en/v2/Git-Tools-Submodules) explains that you can use this feature to integrate another project into your repository while still getting the latest commits from the other repo.

<!-- ![image](static/images/submodule.png "Example of a git submodule") -->
![This is an image](/images/submodule.png "Example of a git submodule")

Image 1: An illustration of a git repository with an embedded submodule (source: Own image)

By doing I can fetch the latest changes made to the hugo theme I used to avoid security issues or get the latest features just by running a simple `git pull`. The best thing is that you can user submodules in both directions: push and pull.

## Automating the deployment process

As good administrators are usually lazy, which means the automate recurring tasks, you can create another submodule to easily publish the latest commits directly to github pages. For the automatic deployment to github the [hugo project](https://gohugo.io/hosting-and-deployment/hosting-on-github/) also tells you how to do this. You just have to add another submodule to your github pages repository. As soon as you've finished this it's pretty straightforward.

```Bash
#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

# Build the project.
# If you use a theme add quotation marks nasty errors when creating your pages.
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
```

So as soon as I run this bash script my latest changes are directly live on github and so also on the website. Pretty simple isn't it? This enables me to continously update my blog just by running a simple shell script.

