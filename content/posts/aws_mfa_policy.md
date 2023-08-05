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

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowViewAccountInfo",
      "Effect": "Allow",
      "Action": [
        "iam:GetAccountPasswordPolicy",
        "iam:GetAccountSummary",
        "iam:ListVirtualMFADevices"
      ],
      "Resource": [
        "arn:aws:iam::orga_id:user/$${aws:username}",
        "arn:aws:iam::orga_id:mfa/*"
      ]
    },
    {
      "Sid": "AllowManageOwnPasswords",
      "Effect": "Allow",
      "Action": [
        "iam:ChangePassword",
        "iam:GetUser"
      ],
      "Resource": "arn:aws:iam::orga_id:user/$${aws:username}"
    },
    {
      "Sid": "AllowManageOwnAccessKeys",
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey",
        "iam:ListAccessKeys",
        "iam:UpdateAccessKey"
      ],
      "Resource": "arn:aws:iam::orga_id:user/$${aws:username}"
    },
    {
      "Sid": "AllowManageOwnSigningCertificates",
      "Effect": "Allow",
      "Action": [
        "iam:DeleteSigningCertificate",
        "iam:ListSigningCertificates",
        "iam:UpdateSigningCertificate",
        "iam:UploadSigningCertificate"
      ],
      "Resource": "arn:aws:iam::orga_id:user/$${aws:username}"
    },
    {
      "Sid": "AllowManageOwnSSHPublicKeys",
      "Effect": "Allow",
      "Action": [
        "iam:DeleteSSHPublicKey",
        "iam:GetSSHPublicKey",
        "iam:ListSSHPublicKeys",
        "iam:UpdateSSHPublicKey",
        "iam:UploadSSHPublicKey"
      ],
      "Resource": "arn:aws:iam::orga_id:user/$${aws:username}"
    },
    {
      "Sid": "AllowManageOwnGitCredentials",
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceSpecificCredential",
        "iam:DeleteServiceSpecificCredential",
        "iam:ListServiceSpecificCredentials",
        "iam:ResetServiceSpecificCredential",
        "iam:UpdateServiceSpecificCredential"
      ],
      "Resource": "arn:aws:iam::orga_id:user/$${aws:username}"
    },
    {
      "Sid": "AllowManageOwnUserMFA",
      "Effect": "Allow",
      "Action": [
        "iam:DeactivateMFADevice",
        "iam:EnableMFADevice",
        "iam:ListMFADevices",
        "iam:ResyncMFADevice"
      ],
      "Resource": "arn:aws:iam::orga_id:user/$${aws:username}"
    },
    {
      "Sid": "AllowUserToCreateVirtualMFADevice",
      "Effect": "Allow",
      "Action": [
        "iam:CreateVirtualMFADevice",
        "iam:DeleteVirtualMFADevice"
      ],
      "Resource": "arn:aws:iam::orga_id:mfa/*"
    },
    {
      "Sid": "AllowUserToDeactivateTheirOwnMFAOnlyWhenUsingMFA",
      "Effect": "Allow",
      "Action": [
        "iam:DeactivateMFADevice"
      ],
      "Resource": [
        "arn:aws:iam::orga_id:user/$${aws:username}"
      ],
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    },
    {
      "Sid": "BlockMostAccessUnlessSignedInWithMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:ChangePassword",
        "iam:CreateVirtualMFADevice",
        "iam:DeleteVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "iam:ListMFADevices",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "sts:GetSessionToken"
      ],
      "Resource": [
        "arn:aws:iam::orga_id:user/$${aws:username}",
        "arn:aws:iam::orga_id:mfa/*"
      ],
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "false",
          "aws:ViaAWSService": "false"
        }
      }
    }
  ]
}
```

>Hint: You have to replace `orga_id` with your own organization ID.

## Disabling other services

## Conclusion
