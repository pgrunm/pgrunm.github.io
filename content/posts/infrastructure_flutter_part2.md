---
draft: true
date: 2021-06-12T21:09:31+01:00
title: "Developing Flutter apps with cloud infrastructure: Part 2"
description: "Trying to use Nginx as forward proxy, but failing."
slug: ""
tags: [DevOps, Flutter, AWS, Jenkins, Terraform]
externalLink: ""
series: []
---

## Introduction

Hello again dear reader. This is the 2nd part of the AWS Flutter development series. The first part covered how to create the required infrastructure in AWS with Terraform. This part will cover how the the required Jenkins containers (master/agent) are set up. Let's dive into it.

## Container setups

### Jenkins Master container

The jenkins master container is the brain of the entire application. It controls and schedules new ECS Jenkins agents if necessary. Every piece of configuration is populated from environment variables as you can see in the dockerfile for the Jenkins master: 

<!-- Source Code Jenkins Master Dockerfile -->
```dockerfile
FROM jenkins/jenkins:2.263.1-lts

# Install the Jenkins Plugins from the plugins text file
# like described in the docs:
# https://github.com/jenkinsci/docker#plugin-installation-manager-cli-preview
COPY code/docker/Test/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

# Copy the groovy config file
COPY code/docker/Test/initialConfig.groovy /usr/share/jenkins/ref/init.groovy.d/initialConfigs.groovy
COPY code/docker/Test/jenkins.yaml /usr/share/jenkins/ref/jenkins.yaml

# Create the app pipeline from config files
COPY code/docker/Test/helloWorld.xml /usr/share/jenkins/ref/jobs/Hello-World/config.xml
COPY code/docker/Test/appConfig.xml /usr/share/jenkins/ref/jobs/Flutter-App/config.xml

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
```

<!-- Link zum Repo hier einfügen -->
If you want to have a look at the sourcecode you can find it again inside the [Github repository](https://github.com/pgrunm/aws_jenkins_flutter) I created earlier for this series. The dockerfile basically copys required configuration files into the container so they are stored inside the container.

Another idea would be to store the configuration inside environment variables (if it's supported) or even better: to store the configuration in a volume, which the container can mount. With this you don't have to create a new container every time you change the config. Instead you just have to reboot your container.

| File                          | Explanation                                  |
| ----------------------------- | -------------------------------------------- |
| plugins.txt                   | Contains a list with plugins to be installed |
| initialConfigs.groovy         | Groovy settings                              |
| jenkins.yaml                  | Jenkins main configuration file              |
| Helloworld.xml, appconfig.xml | Pipeline configuration files                 |

## Conclusion

<!-- List to repo, further information, link to next article -->