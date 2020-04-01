---
draft: true
date: 2020-04-09T21:45:07+01:00
title: "GPT and MBR: Moving from MBR to GPT"
description: "Managing my new Raspberry Pi with Ansible."
slug: "" 
tags: [Linux, Windows, Hard Drive, GPT, MBR]
externalLink: ""
series: []
---

## Intro

About a year ago I bought a used hard drive from a colleague of mine. This HDD has a size of 3 TiB and is supposed to hold big files like videos, images and some games that are neigher read nor write intensive. Unfortunately I moved from my previous HDD with a Master Boot Record (MBR) and kept using the MBR.

This turned out to be a problem since MBR doesn't support partitions larger than 2 TiB so I could not use all of my 3 TiB drive.

### A brief overview about MBR

I don't want to get soo deep into history about MBR because it is pretty old. If you're interested in it's history you can find a lot [about this](https://en.wikipedia.org/wiki/Master_boot_record) on the internet. The MBR contains the bootsector of a disk and starts your operating system.

As the MBR is pretty old one of it's downsides is the size limitation of partitions up to 2 TiB. You also can not have more than four primary partitions. If you want to have than four partitions you have to convert a primary partition to an extended partition. This extended partition can hold multiple logical partitions within.

## The new GUID partition table (GPT)

After the standardization of the Unified Extensible Firmware Interface (UEFI) where the GPT is also part of BIOS has been used less and instead UEFI became more popular. The GPT of a disk consists of

- A master boot record in sector 0 (so MBR only operating systems can still boot)
- A primary [GUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) partition table
- At least 128 partitions and drives with a capacity up 8 [ZiB](https://en.wikipedia.org/wiki/Binary_prefix#zebi)
- Supported operating systems: GNU/Linux, [Windows Vista and later](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-and-gpt-faq#can-windows-vista-windows-server-2008-and-later-read-write-and-boot-from-gpt-disks)

## Moving from MBR to GPT

I wanted to this for longer but until now I didn't have time to read about this topic on the internet. Before making any changes to your system always make up a backup and try to restore some files.

<!-- Source of image: By User:Kbolino., CC BY-SA 2.5, https://commons.wikimedia.org/w/index.php?curid=3036588 -->

<!-- 
https://rodsbooks.com/gdisk/
gdisk /dev/sda
r
f
w
-> Fertig

Unterschiede
Vor-/Nachteile
 -->

## Summary: GPT vs MBR

 |                                | MBR                                                         | GPT |
 | ------------------------------ | ----------------------------------------------------------- | --- |
 | Number of supported partitions | Up to 4 primary partions or more with an extended partition |     |
 | Maximum size of partitions     | Maximum size is 2 TiB per partition                         |     |
 | Supports BIOS / UEFI           | Only BIOS supported                                         |     |
 | Supported operating systems:   |                                                             |     |
