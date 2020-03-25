---
title: "Building my new blog: Part 1"
date: 2020-02-01T14:31:31+01:00
draft: false
tags: [hugo, first pos]
---

I wanted to create a blog for a long time already, but because of university I had not much spare time. Finally I found some time to create my blog and this post will contain some background information about the software I'm using, where it's hosted etc. Enjoy my first post!

## What to use

The first question I asked myself was: What software I'm going to use for my blog? Maybe Wordpress or Joomla for example? Lately you can read a lot about critcal vulnerabilities in Wordpress or rarely maintained plugins. So this wasn't an option for me, because security is a must have.

Recently I played some Terraria with my girlfriend on the same computer by using an open source software called [Universal Split Screen](https://universalsplitscreen.github.io/docs/guides/terraria/). I really liked the clear design of the page which is apparently hosted by Github pages. I read a little bit of the background and found out that you can easily create and host static sites this technology. Unfortunately there was one problem: This is based on [Jekyll](https://jekyllrb.com/) which uses Ruby as programming language. As I'm already familiar with Python, Go and some other languages I wasn't interested in learning Ruby just for this project.

Fortunately I found [Hugo](https://gohugo.io/) which uses Google's Go as programming languages and enables you to create pages from markdown. This is really great, because markdown is super simple and Hugo became my favorite for the project.

<!-- Some more information of the benefits:https://gohugo.io/about/benefits/ -->

## Where to host

The next question I asked myself: Where do I want to host my new blog? I wanted to have it quick and simple (you can call it [KISS](https://en.wikipedia.org/wiki/KISS_principle)). As mentioned earlier, if you have a Github account you can create a personal page to host static pages. I never used this feature before but always wanted to, [Github also explains this really good](https://pages.github.com/) and the [Hugo project also explains you how to use Github pages](https://gohugo.io/hosting-and-deployment/hosting-on-github/).

This question was easy to answer.

## How to set up the website

I mainly used the Hugo documentation like the [quick start guide](https://gohugo.io/getting-started/quick-start/), the [usage guide](https://gohugo.io/getting-started/usage/)

Another important page is the [configuration overview](https://gohugo.io/getting-started/configuration/), where Hugo tells you what you can enable or disable with the config file. The hardest part was of course designing and creating the content like the home page or this first post :-).

I hope you enjoyed the first part, in the next part I'm going to tell you a bit more how I'm publishing new posts and the git structure I'm using.
