---
draft: false
date: 2021-06-21T23:00:00+01:00
title: "Developing Flutter apps with cloud infrastructure: Part 2"
description: "Creating a Jenkins pipeline in AWS."
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

The file above contains the settings to configure the Jenkins master. The settings are take from environment variables, which are created by the Terraform files from [part 1](/posts/infrastructure_flutter_part1). Just to mention a few important points:

- Admin username and password are configured from environmental variables
- Logging is configured
- Storage for artifacts for the Jenkins S3 plugin is configured and
- configuration for test environment is stored (just a hint: store this in in AWS secrets manager or something like, because environmental variables are **visible** from outside!)

The other files are not that interesting, but you can find them inside the [Github repository](https://github.com/pgrunm/aws_jenkins_flutter/tree/master/docker).

### Jenkins Agent configuration file

On the other hand the is the configuration for the Jenkins agent. The following listing shows the content of the dockerfile:

```dockerfile
FROM jenkins/inbound-agent:4.6-1-alpine
# Prerequisites
# Required for Alpine Linux as it contains no curl
# Ruby stuff required for installation of Fastlane
USER root
RUN apk --no-cache add curl ruby ruby-dev g++ make openssl

# Install lcov, currently in Edge branch, testing repo
RUN apk --no-cache add lcov \
--repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing

# Required Settings for Fastlane to work
ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
# Install the Fastlane Ruby package
RUN gem install fastlane -N

# Create a new user
USER jenkins
WORKDIR /home/jenkins

# Install Android stuff
RUN mkdir -p Android/sdk/
ENV ANDROID_SDK_ROOT /home/jenkins/Android/Sdk
RUN mkdir -p .android && touch .android/repositories.cfg

# Setup Android SDK
RUN wget -q -O sdk-tools.zip \
https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip
RUN unzip sdk-tools.zip && rm sdk-tools.zip
RUN mv -v cmdline-tools Android/sdk/cmdline-tools/
RUN cd Android/sdk/cmdline-tools/bin && yes | \
./sdkmanager --sdk_root=$ANDROID_SDK_ROOT --licenses
RUN cd Android/sdk/cmdline-tools/bin && \
./sdkmanager --sdk_root=$ANDROID_SDK_ROOT "build-tools;29.0.3" "patcher;v4" \
"platform-tools" "platforms;android-29" "sources;android-29"

# Download Flutter SDK
RUN git clone https://github.com/flutter/flutter.git

# Update Path Variable with all installed tools
ENV PATH "$PATH:/home/jenkins/flutter/bin"

# Add Slyph Package for Integration Tests
RUN flutter pub global activate sylph 

ENV PATH "$PATH:/home/jenkins/.pub-cache/bin"

# Run basic checks to download Dark SDK
RUN flutter doctor
RUN fastlane actions
RUN sylph --help
```

The dockerfile is based on an official Alpine Linux Jenkins agent image, where all the required Jenkins parts are already installed. Other requirements are:

- software required for development and installation purposes
- `lcov` for test coverage
- language and encoding settings (utf-8)
- [Fastlane](https://fastlane.tools/) for deployment in the Google Play and Apple app store
- then the Android SDK is installed inside `/home/jenkins/Android/Sdk`
- afterwards the Flutter SDK is installed (needed for compilation) and last but not least
- [Sylph](https://pub.dev/packages/sylph) is installed for device testing on AWS

As this dockerfile is mainly for testing and demonstration purposes there are also a few debugging commandlets to verify the succesful installation of the tools.

## Description of the workflow

The idea behind this kind of architecture is pretty simple but effective. As soon as you create the infrastructure with Terraform, the Jenkins master is started once everything is created. The master is configured with environmental variables and a config file where to find the Jenkinsfile with instructions. The Jenkinsfile looks like this:

<!-- Jenkinsfile -->
```groovy
pipeline {
    
    agent {
        // Tells the pipeline to use an AWS ECS agent,
        // because of the used label.
        label 'Flutter'
    }

    stages {
        stage('Build') {
            steps {
                echo 'Building..'            
                // Build the Android App
                dir('testing_codelab/step_07/') {
                    sh 'flutter build appbundle'
                    
                    // Archive the Build Artifact on the 
                    // created S3 Bucket.
                    archiveArtifacts "/build/app/outputs/bundle/release/*"
                }
            }
        }
        stage('Check the Code Quality') {
            steps {
                dir('testing_codelab/step_07/') {
                    // Check the Code Quality
                    // Flutter Analyze performs a static analysis
                    // See here for more details: 
                    // https://flutter.dev/docs/reference/flutter-cli#flutter-commands
                    echo 'Doing Code Quality Tests'
                    sh 'flutter analyze'
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('testing_codelab/step_07/') {
                    // Run all unit tests
                    echo 'Doing Unit Tests'
                    // Point to Unit Test directory
                    // Coverage is reported to ./coverage/lcov.info
                    sh 'flutter test --coverage -r expanded test/models/'
                    // Reporting of Unit Test Coverage
                    sh 'lcov -l codecov/*'
                }
            }
        }
        
        stage('Widget Tests') {
            
            steps {
                dir('testing_codelab/step_07/') {
                    // Run all Widget tests on the code
                    echo 'Running Widget Tests'
                    // Runs Widget tests on all files
                    sh 'flutter test --coverage -r expanded test/'
                    // Reporting of Widget Test Coverage
                    sh 'lcov -l codecov/*'
                }
            }
        }
        stage('Integration Tests') {
            steps {
                dir('testing_codelab/step_07/') {
                    // Running integration tests on AWS Devicefarm, uses Sylph and a config file
                    echo 'Running integrations tests on AWS Devicefarm...'
                    sh 'sylph -c sylph.yaml'
                }
            }
        }

        stage('Beta Deployment') {
            // Deploy as Beta Release if no there is no git tag
            when { 
                not { 
                    buildingTag() 
                } 
            }

            steps {
                echo 'Deploying beta version to Play Store'
                sh 'fastlane beta'
            }
        }
        stage('Release Deployment') {
            // Deploy as full release if the current commit contains a git tag
            // Captures screenshots and uploads the app file to playstore
            when { 
                buildingTag() 
            }
            steps {
                echo 'Deploying release version to Play Store'
                sh 'fastlane playstore'
            }
        }
    }
    post {
        // Post Tasks
        always {
            echo "None so far..."
        }
    }
}
```

The cool part from this now on is, you create the infrastructure automatically and as soon everything is available the pipeline is ready to run. The instructions what to do the master gets from the Jenkinsfile which is inside a Github repository (in this case). If you start a build job, the master start an agent, the agent downloads the entire repository and executes everything as listed inside the Jenkinsfile.

## Overview of the pipeline

The pipeline is designed to run in the order as listed inside the Jenkinsfile above:

1. Build an Android app from the source code (the version for iOS requires a device with MacOS)
2. the next step is to check the code quality and to do tests (this step requires lcov as mentioned before)
3. for the last step the build is deployed as beta build, if it contains a tag then it is deployed as productive version to the app stores

## Conclusion

This was the 2nd part of the Flutter AWS series. The next and last part will cover the tests and the deployment process. Thanks for reading! 

<!-- List to repo, further information, link to next article -->
<!-- See more in [part 3 of the series](/posts/infrastructure_flutter_part3). -->
