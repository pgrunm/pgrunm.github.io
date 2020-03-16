---
draft: false
date: 2020-03-16T19:33:10+01:00
title: "Using Prometheus for application metrics"
description: "How to implement metrics for a Go application with Prometheus?"
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

Before just adding any metrics it's important to ask yourself

- What are the most important parts of the application to be instrumented (e. g. successfully processed input)?
- Is the error rate suddenly increasing?
- Does the (average) response time increase?
- Anything else important you need to monitor?
<!-- Noch weitere? Siehe Buch übers Monitoring + Prometheus up & running -->

If you can answer these questions and implement metrics at these spots it's easy to implement metrics for the most important parts of the applications.

### Diving into the code

For my RSS CLI I splittet the code in two different files, where one files hold the main function and the other file all necessary functions. To use the Prometheus metrics globally I had to add them inside the global variable space like this:

```Go
var (
	// This is not the full list but a snapshot.
	// Prometheus variables for metrics
	opsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "rss_reader_total_requests",
		Help: "The total number of processed events",
	})
	cacheHits = promauto.NewCounter(prometheus.CounterOpts{
		Name: "total_number_of_cache_hits",
		Help: "The total number of processed events answered by cache",
	})
	rssRequests = promauto.NewCounter(prometheus.CounterOpts{
		Name: "total_number_of_rss_requests",
		Help: "The total number of requests sent to get rss feeds",
	})

	// See: https://godoc.org/github.com/prometheus/client_golang/prometheus#Summary
	responseTime = prometheus.NewSummary(prometheus.SummaryOpts{
		Name:       "response_time_summary",
		Help:       "The sum of response times.",
		Objectives: map[float64]float64{0.5: 0.05, 0.9: 0.01, 0.99: 0.001},
	})
)
```

You can now access these variables from all over the program and also other files. For example, if a request has been processed successfully the program increments the counter `opsProcessed` by 1 with `opsProcessed.Inc()`. The full sourcecode for the function looks like this:

```Go
// ParseFeeds allows to get feeds from a site.
func ParseFeeds(siteURL, proxyURL string, news chan<- *gofeed.Feed) {

	// Measure the execution time of this function
	defer duration(track("ParseFeeds for site " + siteURL))

	// When finished, write it to the channel
	defer wg.Done()

    // Proxy URL see 
    // https://stackoverflow.com/questions/14661511/setting-up-proxy-for-http-client
	var client http.Client

	// Proxy URL is given
	if len(proxyURL) > 0 {
		proxyURL, err := url.Parse(proxyURL)
		if err != nil {
			fmt.Println(err)
		}

		client = http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL)}}
	} else {
		client = http.Client{}
	}

	item, found := c.Get(siteURL)
	if found {
		//  Type assertion see: https://golangcode.com/convert-interface-to-number/
		news <- item.(*gofeed.Feed)

		// Increase the counter for cache hits
		cacheHits.Inc()
	} else {
		// rate limit the feed parsing
		<-throttle

		rssRequests.Inc()

        // Changed this to NewRequest as the golang docs 
        // says you need this for custom headers
		req, err := http.NewRequest("GET", siteURL, nil)
		if err != nil {
			log.Fatalln(err)
		}

		// Set a custom user header because some site block away default crawlers
		req.Header.Set("User-Agent", "Golang/RSS_Reader by Warryz")

		// Get the Feed of the particular website
		resp, err := client.Do(req)

		if err != nil {
			fmt.Println(err)
		} else {
			defer resp.Body.Close()
			if resp.StatusCode == 200 {
				// Read the response and parse it as string
				body, _ := ioutil.ReadAll(resp.Body)
				fp := gofeed.NewParser()
				feed, _ := fp.ParseString(string(body))

				// Return the feed with all its items.
				if feed != nil {
					c.Set(siteURL, feed, cache.DefaultExpiration)
					news <- feed
				}
			}
		}
	}
}
```

As you can see we now instrumented our application with several metrics that are now displayed with our 2nd webhandler. Everytime I send a request to the webserver the metrics are now adjusted like how many requests were answered by the cache or had to send a request out to the internet.

You can find an official example from Prometheus [here](https://prometheus.io/docs/guides/go-application/). I also found a [presentation of Google's monitoring](https://docs.google.com/presentation/d/1X1rKozAUuF2MVc1YXElFWq9wkcWv3Axdldl8LOH9Vik/edit#slide=id.g598ef96a6_0_1103) on the internet, maybe this helps you too. Thanks for reading and I hope you enjoyed the article!
