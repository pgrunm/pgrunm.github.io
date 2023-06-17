---
title: "Webserver Härtung für die Fernuni Inc."
date: 2023-06-17T00:00:03+00:00
offTheRecord: true
tags: [university, security]
---

# Einleitung

Unsere Aufgabe bestand darin einen Webserver für das Unternehmen Fernuni Inc. bereitzustellen. Da die Fernuni Inc. unter anderem auch Kunden aus dem sogenannten Kritis-Bereich Handel betrieb, sollte die Infrastruktur möglichst umfassend gehärtet sein.

Konkret bestanden unsere Aufgaben aus dem folgenden:

- Installation und Härtung eines Betriebssystems. In unserem Falle haben wir uns für Ubuntu entschieden.
- Containerisierung der bereitgestellten Python Programme.
- Bereitstellung eines Webservers, der die Domains `hello.fernuni` und `messages.fernuni` bedient.
- Absicherung des Systems mit AppArmor.
- Konfiguration Firewallregeln.
- Installation einer MySQL Datenbank.
- Einrichtung regelmäßiger verschlüsselter Datenbank Backups.
- Konfiguration sicherer Firewall Regeln.
- Installation Wireguard.
- Umsetzung angemessener Maßnahmen zur Härtung des Systems und Sicherung des Zugangs zum System.

## Organisation unserer Gruppe

## Härtung des Systems

Ausgabe Ansible Playbook.
<!-- TODO: GIF erzeugen -->
![Alt Text](/images/fuh_project/demo.gif)