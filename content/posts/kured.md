---
title: "Automating Kubernetes operating system updates with Kured, kOps and Flatcar"
date: 2023-07-15T10:40:30+02:00
draft: false
tags: [kubernetes, cncf, security, flatcar, kops]
---

## Introduction

Hello everyone, it's time for a new post. 

As you may know, operating system updates are a crucial part of IT security. In cloud environments you may have up to thousands of virtual servers, where no engineer can manually update these servers. So what to do, if you want to automate these operating system updates?

## The solution

Fortunately, there is a great solution to this problem. This solution is called [Kured](https://kured.dev/). Kured enables you as a Kubernetes administrator to automate operating system updates. You can choose between different settings like

- Day of week, when updates should be installed (e. g. monday to fridays)
- Start and end time, when updates should be installed (my suggestion: office times like 8 to 2)
- Labels and annotations that should be added before/while and after the update
- Webhook notification like Slack or Teams
- How many servers should restart in parallel
- "Cooldown phase", how long to wait between each server

Kured looks for a file, that says the servers needs to rebooted like `/var/run/reboot-required`. The file itself can be configured in Kured and as soon this file is detected, Kured coordinates the reboot between all of the servers. If you configure to reboot only one server at a time, Kured will managed this by itself.

>But watch out, deadlocks can happen, if the rebooting server is deleted while restarted!

### Installation and configuration of Kured

If you want to install Kured, it's the easiest way to install it with Helm. But first, we're going to prepare the configuration for Kured. Some noteworthy settings are:

- We want to allow reboots only between 8 to 15 UTC
- Allow reboots only within Mondays to Thursdays
- Add a notification url
- Add settings for the automatic release of the lock, as described [here](https://kured.dev/docs/operation/#automatic-unlock)
- Add labels and annotations to the nodes, see [here](https://kured.dev/docs/configuration/)

The overall values file will look like this:

```yaml
configuration:
    # When to finish the reboot window (default "23:59")
    endTime: "15" 
    # Schedule reboots only on these days (default [mo-sun])
    rebootDays: [mon, tue, wed, thu] 
    # Notification URL with the syntax as following: 
    # https://containrrr.dev/shoutrrr/services/overview/
    notifyUrl: "https://webhook.example.com" 
    # only reboot after this time (default "0:00")
    startTime: "8" 
    # time-zone to use (valid zones from "time" golang package)
    timeZone: "UTC" 
    # log format specified as text or json, defaults to text
    logFormat: "text"
    # How long to hold the lock after rebooting:
    lockReleaseDelay: 5m
    # Automatically release the lock after 30 mins if anything went wrong
    lockTtl: 30m
    # Add annotations to the nodes
    annotateNodes: true
    # Labels, see 
    # https://kured.dev/docs/configuration/#adding-node-labels-before-and-after-reboots
    preRebootNodeLabels: [kured=needs-updates]
    postRebootNodeLabels: [kured=finished-updates]
```

These values allow us to configure Kured as we want, when installing it with Helm. You can find more information on the Kured [installation page](https://kured.dev/docs/).

Finally, we want to install Kured with Helm. To do so just simply run

```shell
helm repo add kubereboot https://kubereboot.github.io/charts
helm install my-release kubereboot/kured
```

That's it! You've successfully installed Kured!🥳

## Using Kured together with kOps and Flatcar

kOps is a great tool, which allows you to easily setup and maintain a Kubernetes cluster on the major cloud providers. kOps supports a number of different operating systems. One of them is Flatcar, which is a friendly fork of the former ContainerOS.

Flatcar supports A/B partitions, where the running OS partitions is read only, while system updates are written to the other partition. It's also an OS designed for container usage, so it fits perfectly in running a Kubernetes cluster.

I'm not explaining in this post, how to create a new kOps managed Kubernetes cluster in this post. The relevant part for managing the system updates for your nodes is to set the the `updatePolicy` to external, like this:

```yaml
updatePolicy: external
```

kOps used to write in their [documentation](https://kops.sigs.k8s.io/operations/images/#security-updates), that they're managing OS updates for Flatcar, but this was removed in an earlier update, but is still inside their documentation.

Once you configured your nodegroup to use an external policy, we're done with the kOps part and the Kured configuration is in place, we finally can test it.

>**Hint**: You may have to run a [rolling update](https://kops.sigs.k8s.io/operations/rolling-update/) of your cluster with the `kops rolling-update cluster` command.

Simply create a file with `touch /var/run/reboot-required` on any Kubernetes node and watch the reboot magic happen.

## Conclusion

In this blog post, I showed you how to combine the great Kured tool with kOps, to manage automatic system updates. I hope you liked the post, if you have any questions, feel free to contact me.