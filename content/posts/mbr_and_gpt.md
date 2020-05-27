---
draft: false
date: 2020-04-19T21:45:07+01:00
title: "GPT and MBR: Moving from MBR to GPT"
description: "Information on GPT and how to move from MBR to GPT."
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

I wanted to this for longer but until now I didn't have time to read about this topic on the internet. Before making any changes to your system always make up a backup and try to restore some files. I really can recommend using [Clonezilla](https://clonezilla.org/) for this, as it's open source and works with many many filesystems (you should give it a try).

### Converting the Master Boot Record

You can easily convert the Master Boot Record with the open source program [gdisk](https://www.rodsbooks.com/gdisk/walkthrough.html). It is already included in the [Gparted Live distribution](https://gparted.org/livecd.php), which you just have to boot and open up a terminal.

Inside the terminal you just have the following commands:

```bash
# Run this to the appropiate disk in my casee /dev/sda
gdisk /dev/sda
# Enter the recovery menu with r
r
# Load the MBR and create a GPT from this
f
# Write the data to disk
w
```

Pretty simple isn't it? I had to search a little while for this on the internet and you can find a lot of stuff from 3rd party tools. I found a good way for me to this with just four basic commands.
<!-- Source of image: By User:Kbolino., CC BY-SA 2.5, https://commons.wikimedia.org/w/index.php?curid=3036588 -->

## Summary: GPT vs MBR

To sum up you can find in this table which explains some of the differences between the MBR and the GPT.

 |                                | MBR                                                         | GPT                                                                                                               |
 | ------------------------------ | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
 | Number of supported partitions | Up to 4 primary partions or more with an extended partition | Up to 128 partitions (natively!)                                                                                  |
 | Maximum size of partitions     | Maximum size is 2 TiB per partition                         | According to [IBM](https://developer.ibm.com/tutorials/l-gpt/) support for up to eight zebibytes                  |
 | Supports BIOS / UEFI           | Only BIOS supported                                         | Yes/Yes                                                                                                           |
 | Supported operating systems:   | Almost any operating system                                 | More information can be found [here](https://en.wikipedia.org/wiki/GUID_Partition_Table#Operating-system_support) |

If you're using newer hardware (like a mainboard with an UEFI) it is a good idea to use GPT instead of the old fashioned MBR.

### Further reading

- The [GPT fdisk tutorial](https://rodsbooks.com/gdisk/).
- IBM's [Linux and GPT](https://developer.ibm.com/tutorials/l-gpt/) tutorial.
