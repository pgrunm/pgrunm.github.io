---
draft: false
date: 2020-03-28T18:45:07+01:00
title: Setting up the new Raspberry Pi 4 with Ansible
description: "Managing my new Raspberry Pi with Ansible."
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

To be able to configure settings with Ansible one way to manage my Pi is to add it's IP address to my hosts file which could like this:

```Yaml
---
all:
  vars:
    ansible_ssh_user: pascal
    user_ssh_pub_key: "{{ lookup('file','~/ssh_key_raspi') }}"

  children:
    pis:
      # List of Raspberry Pis
      hosts:
        192.168.200.150:
    new_pis:
      # Contains only new Pis
      hosts:
        192.168.200.151:  
```

You may notice that there are two different groups: `pis` and `new_pis`. This is because the new Raspberry Pi is still naked and there is no public SSH key deposited which allows seamless remote access.

When I created my new SSH key pair I looked for technical recommendations from German Federal Office for Information Security (or BSI in German). They recommend in the directive [TR-02102-4](https://www.bsi.bund.de/EN/Publications/TechnicalGuidelines/tr02102/tr02102_node.html) things like

- use only SSH version 2
- enable only public key authentication
- the use of a key algorithm like ecdsa-sha2-* (which you according to current knowledge can use until at least 2025)

### Making the Pi managed by SSH key

Like mentioned before I generated already before an SSH key like described [here](https://wiki.archlinux.org/index.php/SSH_keys#Ed25519). With this playbook I created a the new user `pascal` for me, copied the ssh onto the remote machine and deleted the default user pi for security reasons.

```Yaml
---
- hosts: new_pis
  tasks:
    - name: Add the user 'pascal'
      user:
        name: pascal

    - name: Set authorized key taken from file
      authorized_key:
        user: "pascal"
        state: present
        key: "{{ lookup('file', '/home/pascal/pub') }}"
    - name: Remove the default user 'pi'
      user:
        name: pi
        ensure: absent
        ansible_ssh_user: pascal
```

Now I already can move the IP address in the `hosts.yml` file from `new_pis` to `pis` as it's now accessible with my SSH key.

### Some more configuration

There are more settings that I need to configure like

- Enable passwordless sudo for my account
- Disable password based authentication (so only public key based authentication is enabled)
- Disable root login

```Yaml
---
- hosts: new_pis
  # You may need to add --ask-become-pass -b on the command line
  become: yes
  tasks:
    - name: Allow passwordless sudo for my account
      lineinfile:
        path: /etc/sudoers
        state: present
        line: "pascal ALL=(ALL) NOPASSWD: ALL"
        validate: "visudo -cf %s"

    - name: Disallow password authentication
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "^PasswordAuthentication"
        line: "PasswordAuthentication no"
        state: present
      notify:
        - Restart ssh

    - name: Disable root login
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "^PermitRootLogin"
        line: "PermitRootLogin no"
        state: present

    - name: Restart ssh daemon
      service:
        name: sshd
        state: restarted
```

While running this I of course had to add my sudo password with the [commandline parameter](https://docs.ansible.com/ansible/latest/user_guide/become.html#become-command-line-options) `-K` to supply the password to become root.

<!-- See: https://ansible.github.io/workshops/exercises/ansible_rhel/1.5-handlers/#step-52---handlers -->
When all the settings are implemented the SSH daemon is restarted by a [handler](https://docs.ansible.com/ansible/latest/user_guide/playbooks_intro.html#handlers-running-operations-on-change).

### Getting the latest updates

One last step before the Pi is ready to serve it's duty is installing the latest updates. You can do this of course by running an `apt update; apt upgrade -y` on the commandline, but like I mentioned earlier I don't want to run commands by hand. So I created another playbook for this purpose:

```Yaml
---
- hosts: pis
  become: yes
  tasks:
    - name: Ping the Raspi
      ping:

    # See: https://docs.ansible.com/ansible/latest/modules/apt_module.html#examples
    - name: Run apt update
      apt:
        update_cache: yes
      become: true

    - name: Run apt upgrade
      apt:
        name: "*"
        state: latest
      become: true
```

You may noticed that I'm using here the [apt module](https://docs.ansible.com/ansible/latest/modules/apt_module.html) because I'm using raspbian. This allows me to run `apt update` and `apt upgrade`.

There is also the generic [package module](https://docs.ansible.com/ansible/latest/modules/package_module.html) which allows you to write playbooks that work with any package manager. Unfortunately this doesn't allow you to just get the latest updates so I'm using the apt module here.

## Conclusion

The new Raspberry Pi 4 is now prepared and ready for computing. It can be completely managed by Ansible to do things like installing updates or software, managing users or even installing applications (which of course will happen later).

I hope you enjoyed reading this article and have a nice day!
