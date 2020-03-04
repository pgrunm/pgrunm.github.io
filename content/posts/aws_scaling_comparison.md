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

The Python script handles the logic which url to call and how long to wait. The following Powershell snippet runs Locust to call the web service and create the load.

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

This is how I created the load on my service.

## Testing different architectures

### The three tier architecture

At the beginning I started with the most basic and well known three tier architecture. This architecture contains the client (a browser), a webserver and a database. As I created this project in Go I just had to use Go's builtin webserver to create a simple webserver which would serve requests.

As this is a clound only project the webserver is located on a AWS EC2 micro t.3 instance in Frankfurt. For the database I used an AWS RDS MariaDB instance which I prefer over MySQL. In the following code snippet you can see the internals of this service: everytime the service receives a requests it querys the database and returns the results.
<!-- Hier Quelltext einfügen -->

This is a pretty basic setup which only took one or two hours to setup which is a real advantadge to me. On the opposite side this setup isn't very scalable except in a vertical direction.

When I stressed the service with Locust a little bit the performance at the start was fine, but in the end the webserver wasn't able to handle the load at all. The error rate went up and requests were not served or had to wait for a long time to get an answer.

<!-- Hier Messwerte einfügen -->

The more the load increases the more the performance goes down. To mitigate this I implemented a simple cache.

### Implementing a caching layer

AWS offers the Elasticache service to increase the performance applications by speeding up database querys for example. Instead of calling the database directly you first look inside the cache, if there is an entry for your request then it's directly answered from the cache. Otherwise you still need to call the database.

It can be pretty effective to use a cache as this reduces the load on your database and you may can scale down your RDS database instance which reduces your running costs.
