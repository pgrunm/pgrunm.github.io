---
draft: true
date: 2020-02-26T19:33:10+01:00
title: "Scaling expriments with different AWS services"
description: "I tested out the scaling abilities of different AWS services by creating a dummy application and stress tested them with Locust."
slug: "" 
tags: [AWS, Go, API, Scalability]
externalLink: ""
series: []
---

As part of my studies I had to write an assigment in the module electronic business. I decided to develop some kind of dummy REST api application where I could try different architectures. The reason for me to try this out was to see how the performance changes over time if you increase the load.

I decided to use Go for this project, because it was designed for scalable cloud architectures and if you compile your code you just get a single binary file which you just have to upload to your machine and execute.

## The load testing tool

As I'm also really familar with Python I really enjoy the tool [Locust](https://locust.io) which enables you to stress test your services by simulating a different number of users who access your service by http(s). The best thing about Locust is that it's all code.

```Python
from locust import HttpLocust, TaskSet, between
from random import randrange

# Opening the website i.e. http://example.com/customerdata/123
# The actual hostname is specified and the Powershell script following.
def index(l):
    l.client.get(f'/customerdata/{randrange(1, 4500)}')

class UserBehavior(TaskSet):
    tasks = {index: 1}
    # Things to do before doing anything else.


class WebsiteUser(HttpLocust):
    task_set = UserBehavior
    # Definition of the user behavior: Wait at least 5 seconds and maximum 9 seconds.
    wait_time = between(5.0, 9.0)
```

The Python script handles the logic which url to call and how long to wait. The following Powershell snippet runs Locust to call the web service.

```Powershell
param(
    # This parameter allows you to enter a hostname just by adding a -Hostname.
    $Hostname
)

# This will be written to the file name.
$testCase = "three_tier"

# How many users do we want to simulate?
$numberOfUsersToSimulate = 50, 100, 200, 400, 800, 1500

# AWS Hostname
if ($null -eq $Host) {
    $Hostname = Read-Host -Prompt "Please enter the AWS Hostname"
}

foreach ($users in $numberOfUsersToSimulate) {
    $testWithUsers = $testCase + "_" + $users

    # Executing the Python file.
    locust -f .\Locust\Load_Test.py \
    --no-web \ # Don't run the web interface
    -c $users \ # Simulate x users.
    -r 10 \ # Number of created users per second.
    --step-load \ # Increase the load in steps.
    --step-clients ($users/10) \ # Increase the load by 10 percent every step.
    --step-time 15s \ # After 1.5 minutes the load reaches 100%.
    -t 3m \ # The performance test runs 3 minutes overall.
    --csv=Results/$testWithUsers \ # Save the measured data in a csv file.
    --host="http://$($Hostname):10000" \ # This is the hostname on tcp port 10000.
    --only-summary # Print only a summary once finished.
}

```
