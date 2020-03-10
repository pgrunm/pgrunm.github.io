---
draft: true
date: 2020-03-13T19:33:10+01:00
title: "Using Prometheus for application metrics"
description: "I tested out the scaling abilities of different AWS services by creating a dummy application and stress tested them with Locust."
slug: "" 
tags: [Go, Monitoring, Metrics, Prometheus]
externalLink: ""
series: []
---

<!-- 
URLs:

https://prometheus.io/docs/guides/go-application/
https://docs.google.com/presentation/d/1X1rKozAUuF2MVc1YXElFWq9wkcWv3Axdldl8LOH9Vik/edit#slide=id.g598ef96a6_0_1233
-->

One really important aspect of system and application engineering is monitoring. How do you know if your application, script or system is fine? Google for example uses their own software (called [Borgmon](https://landing.google.com/sre/sre-book/chapters/practical-alerting/)) for monitoring. The open source software Prometheus allows to capture time-series data in order to monitor different statistics of an application like Borgmon does. Let's see how we can do this on our own.

## The basics of Prometheus

Some time ago I wrote a [small Go application](https://github.com/pgrunm/RSS_CLI/tree/master) which parses RSS feeds and displays them as a simple html overview with a local webserver. Right now you can see some statistics like the time it took to download and render all feeds inside the console. As this is nice to know it's difficult to monitor this.

Prometheus allows us to add some code inside our application to add another http listener where the metrics are displayed. As soon as we added this handler we can add different [metric types](https://prometheus.io/docs/concepts/metric_types/) like counters or gauges.

To add the webhandler is just had to use the following:

```Go
// Adding the Prmetheus HTTP handler
http.Handle("/metrics", promhttp.Handler())
go http.ListenAndServe(":2112", nil)
```

Do mind the keyword `go` here. This ensures that the http handler runs inside a [Goroutine](https://gobyexample.com/goroutines) which is executed asynchronously. By using this routine all requests to the metrics endpoint are handled by this routine without the need to wait for a response. If you would leave the `go` keyword the 2nd http handler would not be started.

As soon as you add the http handler some default Golang metrics are exposed like

- Total http responses (statuscode 200, 500 and 503)
- number of Go threads
- seconds since start time

This is already helpful but doesn't say too much about our application. Let's add our own metrics.

## Adding metrics for the application
