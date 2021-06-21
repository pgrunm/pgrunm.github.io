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

# Disable the installation wizard
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
```

<!-- Link zum Repo hier einfügen -->
If you want to have a look at the source code you can find it again inside the [Github repository](https://github.com/pgrunm/aws_jenkins_flutter) I created earlier for this series. The dockerfile basically copies the required configuration files into the container so they are stored inside the container.

Another idea would be to store the configuration inside environment variables (if it's supported) or even better: to store the configuration in a volume, which the container can mount. With this you don't have to create a new container every time you change the config. Instead you just have to reboot your container.

| File                             | Content                                      |
| -------------------------------- | -------------------------------------------- |
| plugins.txt                      | Contains a list with plugins to be installed |
| initialConfigs.groovy            | Groovy settings                              |
| jenkins.yaml                     | Jenkins main configuration file              |
| Helloworld.xml and appconfig.xml | Pipeline configuration files                 |

The table above contains a description of every file that is copied inside the Jenkins master container. 

### Jenkins configuration file

The most important file is the `jenks.yaml` file. It contains the settings to configure the Jenkins master and look like this

<!-- Jenkins master config -->
```yml
jenkins:
  slaveAgentPort: 50000
  # System Message which is displayed on the Dashboard.
  systemMessage: Jenkins Master for FOM Bachelor Thesis
  agentProtocols:
    - JNLP4-connect
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
  remotingSecurity:
    enabled: true
  securityRealm:
    local:
      allowsSignup: false
      # Create the local administrator account with data from environment variables
      users:
        - id: ${JENKINS_ADMIN_USERNAME}
          password: ${JENKINS_ADMIN_PASSWORD}
  clouds:
    - ecs:
        credentialsId: ""
        # ECS Cluster ARN
        cluster: ${ECS_CLUSTER_NAME}
        name: ecs-cloud
        # Environment Variable for the AWS Region e. g. eu-central-1
        regionName: ${AWS_REGION_NAME}
        # Local Jenkins URL, also populated by environment variable,
        # default is master.jenkins.local
        jenkinsUrl: ${JENKINS_URL}
        tunnel: ${LOCAL_JENKINS_URL}
        templates:
          - assignPublicIp: true
            # Amount of CPU Resources, configured in Terraform files
            cpu: ${CPU_AMOUNT}
            memoryReservation: ${MEMORY_AMOUNT}
            executionRole: ${EXECUTION_ROLE_ARN}
            # Name of the Docker image used -> also environment file
            image: ${IMAGE_NAME}
            label: Flutter
            launchType: FARGATE
            logDriver: awslogs
            # Logging Options for AWS Cloudwatch,
            # populated mainly by environment variables.
            logDriverOptions:
              - name: awslogs-group
                value: ${LOG_GROUP_NAME}
              - name: awslogs-region
                value: ${AWS_REGION}
              - name: awslogs-stream-prefix
                value: jenkins-agent
            securityGroups: ${SECURITY_GROUP_IDS}
            subnets: ${SUBNETS}
            templateName: jenkins-flutter-agent
            # AWS Fargate platform version, "Latest" refers to 1.3.0 but 1.4.0 is the latest -> environment variable.
            platformVersion: "${PLATFORM_VERSION}"
            # List of environment variables for the Jenkins Agent.
            # Contains stuff like AWS CLI environment variables etc.
            # which are populated in the variables.tf file.
            # Has to be changed, because environment variables are displayed,
            # see https://preview.tinyurl.com/y3eg6kav.
            # Like AWS Configuration as Code Secrets Manager Plugin: 
            # https://plugins.jenkins.io/configuration-as-code-secret-ssm/
            environments:
            - name: "AWS_ACCESS_KEY_ID"
              value: "${AWS_ACCESS_KEY_ID}"
            - name: "AWS_SECRET_ACCESS_KEY"
              value: "${AWS_SECRET_ACCESS_KEY}"
            - name: "AWS_DEFAULT_REGION"
              value: "${AWS_DEFAULT_REGION}"
aws:
  s3:
    # AWS S3 Bucket Name
    container: "${BUCKET_NAME}"
    disableSessionToken: false
    # Bucket Folder
    prefix: "${S3_FOLDER_PREFIX}/"
    useHttp: false
    usePathStyleUrl: false

```

The file above contains the settings to configure the Jenkins master. The settings are take from environment variables, which are created by the Terraform files from [part 1](/posts/infrastructure_flutter_part1).

## Conclusion

<!-- List to repo, further information, link to next article -->