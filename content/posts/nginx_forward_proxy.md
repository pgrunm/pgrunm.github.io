---
draft: false
date: 2020-07-07T18:45:07+01:00
title: Establishing proxy support for an application without proxy support
description: "Trying to use Nginx as forward proxy, but failing."
slug: "" 
tags: [Windows, Apache, Forward Proxy, Nginx]
externalLink: ""
series: []
---

## Introduction

Hello again dear reader :-)! Some time passed since my last blog post, because I have been busy with University, but now since exams are done, I have some more time for creating the latest post. Recently I stumbled upon an application that needed internet access but unfortunately didn't support a proxy server yet. At that point of the project we had to find a way to allow this application to communicate directly with the internet, but without having a direct connection to the internet. This is the topic of this post.

## Overview of the application

The application itself is a HTTP webservice, that allows you to send requests to it which are then forwarded to an SaaS application within the internet. Let's image we're calling our webservice without a configured proxy and this would be the result:

![This is an image](/images/nginx-proxy/communication_wo_proxy.png "Visualization of the architecture without a proxy.")

This is actually a pretty simple schematic of the environment, because I removed any firewalls as well as the proxy server of course. This is the way the developer expected the application to work. Unfortunately it could not access the internet without the proxy server.

## Trying to internet access with an own solution

### Usage of Nginx as forward proxy

As I use the Nginx webserver fairly often this became my first idea to find a solution. Nginx works quite well as a reverse proxy, so why not use it as forward proxy then? If you search around the internet for any articles for this. I found a post on [Stackexchange](https://superuser.com/q/604352), where several answers were made. One replied to use Squid instead, because it does not work with Nginx at all, another replied you can compile it on your own with custom module from Github.

<!-- Problem: Windows -->
The problem now is, that the OS we used was Windows. So we had to compile the code for Windows. Any code from Github. In a production environment. Mhh, not a good idea. In the end I tried a few around and ended up with this Nginx config file:

```apacheconf
http {
    server {
        listen 80;
        listen 443 ssl http2;

        # Path to server certificate
        ssl_certificate example.com.crt;
        ssl_certificate_key example.com.key;

        # Log file directory
        access_log logs/forward_proxy.access.log;
        error_log  logs/forward_proxy.error.log debug;

        location / {

            # proxy (default)
            set $proxy_host "$http_host";
            set $url "$scheme://$http_host$request_uri";

            # Set Proxy header
            proxy_set_header        Host            $http_host;
            proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header        X-Scheme        $scheme;
            proxy_set_header X-Script-Name $request_uri;  

            proxy_redirect off;
            proxy_set_header Host $proxy_host;
            proxy_set_header X-Forwarded-Host $http_host;

            proxy_set_header Request-URL "$scheme://$http_host$request_uri";
            set $test_req "http://$http_host$uri$is_args$args;";

            # Forward the request to the proxy
            proxy_pass "http://123.45.67.89:8080http://$http_host$uri$is_args$args";
        }
    }
}
```

Unfortunately this did not help at all. I used Wireshark to follow the network traffic and saw did some troubleshooting with curl. When I used curl to connect to the proxy server you could see it used the [HTTP CONNECT method](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT). When we tried to use Nginx we just saw a simple `HTTP GET` instead.

At that point I realised we were on the wrong track and had to try something different.

### A different approach with a real forward proxy

The second way we tried was using Apache httpd as forward proxy, as this comes with builtin forward proxy support on Windows. The config file itself was quite long, so I'm just listing the most interesting lines here:

```apacheconf
<VirtualHost *:443>
    SSLEngine on

    # DocumentRoot "${SRVROOT}/htdocs"

    # Path to server certificates
    SSLCertificateFile      "${SRVROOT}\conf\ssl\example.com.crt"
    SSLCertificateKeyFile   "${SRVROOT}\conf\ssl\example.com.key"

    # Forward Proxy
    ProxyRequests On
    ProxyVia On

    <Proxy "/">
        # Require host internal.example.com
        Require host server.internal.org
        Require ip 127.0.0.1
        Require ip 192.168.42.54
        ProxyPass "https://example.com" nocanon

    </Proxy>
    # Pass all requests on to the internal proxy, except for:
    NoProxy "*.internal.org" "192.168.42.0/24"

    # Forward HTTP and HTTPS requests
    ProxyRemote "*" "http://123.45.67.89:8080"
    ProxyRemote "*" "https://123.45.67.89:8080"

    # enable HTTP/2, if available
    Protocols h2 http/1.1
</VirtualHost>

# Intermediate configuration
SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
SSLHonorCipherOrder     off
SSLSessionTickets       off
```

<!-- Config of Apache -->
The Apache webserver was configured to listen on the TCP ports 80 and 443 for default HTTPS. The idea was to forward any requests on both of these ports to the actual SaaS provider on the internet, because the server's webservice was listening on port 8080. To make the server think it's calling the service on the internet we had to edit the local hosts file like this:

```ini
127.0.0.1  example.com
::1        example.com
```

At that point my solution was working quite well. Any traffic the server received on port 80 was forwarded to the proxy server. The next step was to configure the service accordingly to make it work with the proxy solution. But as soon as we started to try out our server we the following message: `Invalid certificate for website example.com`. What happened here?

### Analysis of the server certificate

When I took a look on the actual certificate of the website, I saw that it is using Certificate Transparency:

![This is an image](/images/nginx-proxy/cert.png "Screenshot of the certificate with enabled certificate transparency")

The cool thing about certificate transparency is, that nobody else can issue a certificate for your website without knowing it has been issued. This is a default policy since March 2018 as they are required to support this as mentioned by [Mozilla](https://developer.mozilla.org/en-US/docs/Web/Security/Certificate_Transparency).

So in the end we were able to create proxy support for the application, but it didn't help us because of certificate transparency. :-)

<!-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expect-CT -->