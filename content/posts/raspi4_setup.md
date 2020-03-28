---
draft: true
date: 2020-03-28T18:45:07+01:00
title: Setting up the new Raspberry Pi 4 with Ansible
description: "How to implement metrics for a Go application with Prometheus?"
slug: "" 
tags: [Ansible, Raspberry Pi, Linux]
externalLink: ""
series: []
---

Since June 2019 the new Raspberry Pi 4 is available to buy. It features much more memory (up to 4 GiB), a Gigabit Ethernet port and two USB 3 ports. So there is a lot of power to compute with, but before we can start playing with it, we have to set it up.

One more thing to say: I don't want to manage my Pi by CLI but with Ansible. So any setting or command I'll have to use will be implemented by using an Ansible playbook.

## Preparing the Raspi

As Linux servers are supposed to be used with the commandline I'm using no GUI on my Pi but [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian/). This small image only contains most basic software to run the Raspi. The last thing we have to do is writing the image to an sd card like describe [here](https://www.raspberrypi.org/documentation/installation/installing-images/). 

I want to enable SSH by default at startup. To do this I had to create a file called `ssh` on `/boot`. By doing this the SSH daemon is automatically started on startup.

## Configuring some basic settings
