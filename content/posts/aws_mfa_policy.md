---
title: "Enforcing an AWS MFA Policy and limiting access"
date: 2022-08-25T16:34:16+01:00
draft: true
tags: [security, aws, iam]
---

## Introduction

Hello again, it's been a long time since my last post. In the meantime a lot has changed, but this is not the topic of this article.

Recently I ran into an issue where I noticed that several users within an AWS development organization were able to **add** an own MFA device to their AWS console login, but they were not forced to do so.

Maybe you followed several IT news websites and you can read from time to time about leaks or any other security issues. One of the best ways to protect your account is to enable a `multi factor authentication` (MFA). With this MFA you have to enter your username, your password and a one time password.

This is especially useful in AWS, as you can protect user accounts with an easy setup and minimal loss in convenience but a big security gain. Unfortunately by default a user does not have permission to add or edit it's own MFA device. So how can we enable this?

## Deep dive into enforcing 2FA with an IAM policy

<!-- Bla bla bla to policies -->

## Disabling other services

## Conclusion
