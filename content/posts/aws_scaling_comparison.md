---
draft: false
date: 2020-02-26T19:33:10+01:00
title: "Scaling expriments with different AWS services"
description: "I tested out the scaling abilities of different AWS services by creating a dummy application and stress tested them with Locust."
slug: "" 
tags: [AWS, Go, API, Scalability]
externalLink: ""
series: []
---

As part of my studies I had to write an assigment in the module electronic business. I decided to develop some kind of dummy REST api application where I could try different architectures. The reason for me to try this out was to see how the performance changes over time if you increase the load.

I decided to use Go for this project, because it was designed for scalable cloud architectures and if you compile your code you just get a single binary file which you just have to upload to your machine and execute.

## The load testing tool

As I'm also really familar with Python I really enjoy the tool [Locust](https://locust.io) which enables you to stress test your services by simulating a different number of users who access your service by http(s). The best thing about Locust is that it's all code.

```Python
from locust import HttpLocust, TaskSet, between
from random import randrange

# Opening the website i.e. http://example.com/customerdata/123
# The actual hostname is specified and the Powershell script following.
def index(l):
    l.client.get(f'/customerdata/{randrange(1, 4500)}')

class UserBehavior(TaskSet):
    tasks = {index: 1}
    # Things to do before doing anything else.


class WebsiteUser(HttpLocust):
    task_set = UserBehavior
    # Definition of the user behavior: Wait at least 5 seconds and maximum 9 seconds.
    wait_time = between(5.0, 9.0)
```

The Python script handles the logic which url to call and how long to wait. The following Powershell snippet runs Locust to call the web service and create the load.

```Powershell
param(
    # This parameter allows you to enter a hostname just by adding a -Hostname.
    $Hostname
)

# This will be written to the file name.
$testCase = "three_tier"

# How many users do we want to simulate?
$numberOfUsersToSimulate = 50, 100, 200, 400, 800, 1500

# AWS Hostname
if ($null -eq $Host) {
    $Hostname = Read-Host -Prompt "Please enter the AWS Hostname"
}

foreach ($users in $numberOfUsersToSimulate) {
    $testWithUsers = $testCase + "_" + $users

    # Executing the Python file.
    locust -f .\Locust\Load_Test.py \
    --no-web \ # Don't run the web interface
    -c $users \ # Simulate x users.
    -r 10 \ # Number of created users per second.
    --step-load \ # Increase the load in steps.
    --step-clients ($users/10) \ # Increase the load by 10 percent every step.
    --step-time 15s \ # After 1.5 minutes the load reaches 100%.
    -t 3m \ # The performance test runs 3 minutes overall.
    --csv=Results/$testWithUsers \ # Save the measured data in a csv file.
    --host="http://$($Hostname):10000" \ # This is the hostname on tcp port 10000.
    --only-summary # Print only a summary once finished.
}

```

This is how I created the load on my service.

## Testing different architectures

### The three tier architecture

At the beginning I started with the most basic and well known three tier architecture. This architecture contains the client (a browser), a webserver and a database. As I created this project in Go I just had to use Go's builtin webserver to create a simple webserver which would serve requests.

<!-- Hier Bild zur Architektur einfügen -->
![This is an image](/images/three_tier.png "Visualization of the three tier architecture")

As this is a clound only project the webserver is located on a AWS EC2 micro t.3 instance in Frankfurt. For the database I used an AWS RDS MariaDB instance which I prefer over MySQL. In the following code snippet you can see the internals of this service: everytime the service receives a requests it querys the database and returns the results.

<!-- Hier beginnt der Go Quelltext -->
```Go
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
)

var (
	db  *sql.DB
	err error
)

// Customer - struct for customer data
type Customer struct {
	ID        int    `json:"Id"`
	Surname   string `json:"Surname"`
	Givenname string `json:"Givenname"`
}

// Readings - struct for read data
type Readings struct {
	MeasureID    int    `json:"MeasureID"`
	MeasureDate  string `json:"MeasureDate"`
	MeasureValue int    `json:"MeasureValue"`
}

type myReadings struct {
	Measures []Readings
}

func (reading *myReadings) AddItem(item Readings) {
	reading.Measures = append(reading.Measures, item)
}

func homePage(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Welcome to the API!")
	fmt.Println("Endpoint Hit: Main API page")
}

func returnCustomerData(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	customerID, parseErr := strconv.ParseInt(vars["id"], 10, 32)

	if parseErr != nil {
		println("dbError while parsing a customer id!")
	} else {
		// Prepare statement for reading data
		stmtOut, dbErr := db.Prepare("SELECT Measure_ID, Measure_Date, Value FROM Readings WHERE Customers_ID_FK = ?;")
		if dbErr != nil {
			fmt.Println("Error while creating the sql statement")
		}
		defer stmtOut.Close()

		// Query the customer id store it in customerdata

		rows, dbErr := stmtOut.Query(customerID)
		defer rows.Close()

		customReadingsList := myReadings{}
		var customerReadings Readings

		if dbErr != nil {
			fmt.Println("unable to query user data", customerID, dbErr)
		} else {
			for rows.Next() {

				err := rows.Scan(&customerReadings.MeasureID, &customerReadings.MeasureDate, &customerReadings.MeasureValue)
				if err != nil {
					log.Fatal(err)
				}
				customReadingsList.AddItem(customerReadings)
			}
			json.NewEncoder(w).Encode(customReadingsList)
		}
	}

}

func returnCustomer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	customerID, parseErr := strconv.ParseInt(vars["id"], 10, 32)

	if parseErr != nil {
		println("dbError while parsing a customer id!")
	} else {
		// Prepare statement for reading data
		stmtOut, dbErr := db.Prepare("SELECT Customers_ID, Surname, Givenname FROM Customers WHERE Customers_ID = ?")
		if dbErr != nil {
			fmt.Println("Error while creating the sql statement")
		}
		defer stmtOut.Close()

		var customerData Customer // we "scan" the result in here

		// Query the customer id store it in customerdata
		dbErr = stmtOut.QueryRow(customerID).Scan(&customerData.ID, &customerData.Surname, &customerData.Givenname)
		if dbErr != nil {
			fmt.Println("unable to query user", customerID, dbErr)
		} else {
			fmt.Printf("The name of customer %d is: %s %s", customerData.ID, customerData.Givenname, customerData.Surname)

			json.NewEncoder(w).Encode(customerData)
		}
	}

}

func handleRequests() {
	myRouter := mux.NewRouter().StrictSlash(true)
	myRouter.HandleFunc("/", homePage)
	myRouter.HandleFunc("/customer/{id}", returnCustomer)
	myRouter.HandleFunc("/customerdata/{id}", returnCustomerData)

	// Needed to disable connection timeouts
	srv := &http.Server{
		Addr:         ":10000",
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      myRouter,
	}

	srv.SetKeepAlivesEnabled(false)

	log.Fatal(srv.ListenAndServe())
}

func main() {

	db, err = sql.Open("mysql", "admin:admin@tcp(123.4.5.6)/hausarbeit")
	if err != nil {
		panic(err.Error())
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		panic(err.Error())
	} else {
		fmt.Println("DB connection established!")
	}
	handleRequests()
}

```

This is a pretty basic setup which only took one or two hours to setup which is a real advantadge to me. On the opposite side this setup isn't very scalable except in a vertical direction.

When I stressed the service with Locust a little bit the performance at the start was fine, but in the end the webserver wasn't able to handle the load at all. The error rate went up and requests were not served or had to wait for a long time to get an answer.

<!-- Hier Messwerte einfügen -->
| Number of users | # requests | # failures | Median responsetime | Average response time | Requests/s | Requests Failed/s |
| --------------- | ---------- | ---------- | ------------------- | --------------------- | ---------- | ----------------- |
| 50              | 822        | 0          | 27                  | 28                    | 4.58       | 4.58              |
| 100             | 1632       | 0          | 27                  | 28                    | 9.08       | 9.08              |
| 200             | 3258       | 0          | 27                  | 28                    | 18.15      | 18.15             |
| 400             | 6487       | 0          | 28                  | 31                    | 36.1       | 36.1              |
| 800             | 10589      | 70         | 41                  | 1084                  | 58.98      | 0.39              |
| 1500            | 13078      | 837        | 1100                | 4343                  | 72.74      | 4.66              |

The more the load increases the more the performance goes down, which you can see here in the increasing response time. Also the number of failed requests is increasing. The next thing I tried to mitigate this is by implementing a simple cache with AWS Elasticache.

### Implementing a caching layer

AWS offers the Elasticache service to increase the performance applications by speeding up database querys for example. Instead of calling the database directly you first look inside the cache, if there is an entry for your request then it's directly answered from the cache. Otherwise you still need to call the database.

It can be pretty effective to use a cache as this reduces the load on your database and you may can scale down your RDS database instance which reduces your overall running costs. Another positive effect is the increase in performance you can get by this.

<!-- Hier Bild zur Architektur: Memcached einfügen -->
![This is an image](/images/memcached.png "Visualization of the three tier memcached architecture")

This picture shows almost the same content as the previous one, except the additional cachie where I used the AWS Elasticache for Memcached. I used Memcached for this as it's pretty simple to setup. An alternative would be Redis but in my opinion for the simple purpose of caching strings and numbers Memcached would be sufficient.

I had to modify the code a little bit to the following.

```Go
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/bradfitz/gomemcache/memcache"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
)

var (
	db  *sql.DB
	err error

	// Memcached variable
	mc = *memcache.New("hausarbeit-eb-memcached.dldis0.cfg.euc1.cache.amazonaws.com:11211")
)

// Customer - struct for customer data
type Customer struct {
	ID        int    `json:"Id"`
	Surname   string `json:"Surname"`
	Givenname string `json:"Givenname"`
}

// Readings - struct for read data
type Readings struct {
	MeasureID    int    `json:"MeasureID"`
	MeasureDate  string `json:"MeasureDate"`
	MeasureValue int    `json:"MeasureValue"`
}

type myReadings struct {
	Measures []Readings
}

func (reading *myReadings) AddItem(item Readings) {
	reading.Measures = append(reading.Measures, item)
}

func homePage(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Welcome to the API!")
	fmt.Println("Endpoint Hit: Main API page")
}

func returnCustomerData(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	customerID, parseErr := strconv.ParseInt(vars["id"], 10, 32)

	if parseErr != nil {
		println("dbError while parsing a customer id!")
	} else {
		// Try reading the data from the memcached server
		key := fmt.Sprintf("customerReadings_id_%d", customerID)

		// mc.Get(&memcache.Item{Key: key, Value: []byte(b)})
		it, memErr := mc.Get(key)
		if memErr != nil {
			fmt.Printf("No data for customer id %d in memcached: %s", customerID, memErr)

			// Prepare statement for reading data
			stmtOut, dbErr := db.Prepare("SELECT Measure_ID, Measure_Date, Value FROM Readings WHERE Customers_ID_FK = ?;")
			if dbErr != nil {
				fmt.Println("Error while creating the sql statement")
			}
			defer stmtOut.Close()

			// Query the customer id store it in customerdata

			rows, dbErr := stmtOut.Query(customerID)
			defer rows.Close()

			customReadingsList := myReadings{}
			var customerReadings Readings

			if dbErr != nil {
				fmt.Println("unable to query user data", customerID, dbErr)
			} else {
				for rows.Next() {

					err := rows.Scan(&customerReadings.MeasureID, &customerReadings.MeasureDate, &customerReadings.MeasureValue)
					if err != nil {
						log.Fatal(err)
					}
					customReadingsList.AddItem(customerReadings)
				}
				json.NewEncoder(w).Encode(customReadingsList)
			}
		} else {
			// Output the memcached data.
			w.Write(it.Value)
		}

	}

}

func returnCustomer(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	customerID, parseErr := strconv.ParseInt(vars["id"], 10, 32)

	if parseErr != nil {
		println("dbError while parsing a customer id!")
	} else {
		// Prepare statement for reading data
		stmtOut, dbErr := db.Prepare("SELECT Customers_ID, Surname, Givenname FROM Customers WHERE Customers_ID = ?")
		if dbErr != nil {
			fmt.Println("Error while creating the sql statement")
		}
		defer stmtOut.Close()

		var customerData Customer // we "scan" the result in here

		// Query the customer id store it in customerdata
		dbErr = stmtOut.QueryRow(customerID).Scan(&customerData.ID, &customerData.Surname, &customerData.Givenname)
		if dbErr != nil {
			fmt.Println("unable to query user", customerID, dbErr)
		} else {
			fmt.Printf("The name of customer %d is: %s %s", customerData.ID, customerData.Givenname, customerData.Surname)

			json.NewEncoder(w).Encode(customerData)
		}
	}

}

func handleRequests() {
	myRouter := mux.NewRouter().StrictSlash(true)
	myRouter.HandleFunc("/", homePage)
	myRouter.HandleFunc("/customer/{id}", returnCustomer)
	myRouter.HandleFunc("/customerdata/{id}", returnCustomerData)

	// Needed to disable connection timeouts
	srv := &http.Server{
		Addr:         ":10000",
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      myRouter,
	}

	srv.SetKeepAlivesEnabled(false)

	log.Fatal(srv.ListenAndServe())
}

func loadCustomerDataIntoMemory() {
	// Load the customer data into cached
	stmtOut, dbErr := db.Prepare("SELECT * FROM Customers;")
	if dbErr != nil {
		fmt.Println("Error while creating the sql statement")
	}
	defer stmtOut.Close()

	// Query the customer id store it in customerdata
	rows, dbErr := stmtOut.Query()
	defer rows.Close()

	var customerData Customer // we "scan" the result in here

	if dbErr != nil {
		fmt.Println("unable to load user into memcached", dbErr)
	} else {

		for rows.Next() {
			// ID, Surname, givenname
			err := rows.Scan(&customerData.ID, &customerData.Surname, &customerData.Givenname)
			if err != nil {
				fmt.Println("unable to parse user row into memcached", err)
			}

			b, err := json.Marshal(customerData)
			if err != nil {
				fmt.Println(err)
				continue
			}
			// Format the key and
			key := fmt.Sprintf("customerData_id_%d", customerData.ID)
			//  Save the data to memcached servers
			mc.Set(&memcache.Item{Key: key, Value: []byte(b)})
		}
		fmt.Println("Finished cache creation for customer data.")
	}

}

func loadReadingsDataIntoMemory() {
	// Load the readings data into cache

	// Does not work, we need this user by user

	stmtOut, dbErr := db.Prepare("SELECT DISTINCT Customers_ID_FK FROM Readings;")
	if dbErr != nil {
		fmt.Println("Error while creating the sql statement")
	}
	defer stmtOut.Close()

	// Query the customer id store it in customerdata
	rows, dbErr := stmtOut.Query()
	defer rows.Close()

	if dbErr != nil {
		fmt.Println("unable to query user ids for caching memcached", dbErr)
	} else {
		// Load the user ids
		for rows.Next() {
			customReadingsList := myReadings{}
			var customerReadings Readings
			var customerID int

			err := rows.Scan(&customerID)
			if err != nil {
				// log.Fatal(err)
				fmt.Println("Could not parse user id")
				continue
			}

			stmtOut, dbErr := db.Prepare("SELECT Measure_ID, Measure_Date, Value FROM Readings where Customers_ID_FK = ?;")
			if dbErr != nil {
				fmt.Println("Error while creating the sql statement")
			}
			defer stmtOut.Close()

			// Query the customer id store it in customerdata
			readingRows, dbErr := stmtOut.Query(customerID)
			defer rows.Close()

			if dbErr != nil {
				fmt.Println("unable to query user ids for caching memcached", dbErr)
			} else {
				for readingRows.Next() {
					// IDFK, MeasureID, Date, Value
					err := readingRows.Scan(&customerReadings.MeasureID, &customerReadings.MeasureDate, &customerReadings.MeasureValue)
					if err != nil {
						log.Fatal(err)
					}
					customReadingsList.AddItem(customerReadings)
				}
				// Save the loaded data to memcached by converting it to json
				b, err := json.Marshal(customReadingsList)
				if err != nil {
					fmt.Println(err)
					continue
				}
				// Format the key and
				key := fmt.Sprintf("customerReadings_id_%d", customerID)
				//  Save the data to memcached servers
				mc.Set(&memcache.Item{Key: key, Value: []byte(b)})
			}
		}
	}
	fmt.Println("Finished cache creation for customer readings.")
}

func initSetup() {

	db, err = sql.Open("mysql", "admin:admin@tcp(123.4.5.6)/hausarbeit")
	if err != nil {
		panic(err.Error())
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		panic(err.Error())
	} else {
		fmt.Println("DB connection established!")
	}

	// Load all from the db into memcached
	loadCustomerDataIntoMemory()
	loadReadingsDataIntoMemory()

	// Print when ready to serve
	fmt.Println("Ready to serve traffic...")
}

func main() {
	initSetup()
	handleRequests()
}
```

The code now works as following:

1. At the beginning the cache is created directly from the database.
2. As soon as all entries from the database are available in the cache the webserver starts and the application is ready to server traffic.
3. Every time you call a specific url like <https://example.org/customerdata/12345> the appropiate url handler is called.
4. If you try to receiver customer data for example the program tries to find an entry for the given key inside the cache returns it to you. If it doesn't find a value inside the cache it queries the database.

As database load can increase the more user you have, caching is a good strategy to decrease the response time.

<!-- Messwerte Memcached -->
| Number of users | # requests | # failures | Median responsetime | Average response time | Requests/s | Requests Failed/s |
| --------------- | ---------- | ---------- | ------------------- | --------------------- | ---------- | ----------------- |
| 50              | 824        | 0          | 23                  | 23                    | 4,59       | 0                 |
| 100             | 1637       | 1          | 24                  | 23                    | 9,11       | 0,01              |
| 200             | 3266       | 2          | 25                  | 25                    | 18,18      | 0,01              |
| 400             | 6477       | 3          | 26                  | 31                    | 36,05      | 0,02              |
| 800             | 11112      | 42         | 31                  | 678                   | 61,83      | 0,23              |
| 1500            | 13409      | 804        | 1200                | 4162                  | 74,6       | 4,47              |

As you can see in the table above not only average response time decreased but also the number of failed requests per second decreased. So the cache makes it a little bit better but in my opinion there is still air upward.

### Scaling out with a load balancer and multiple processes

As you saw in the last table I tried the best to increase the load the example application could handle. As the three tier architecture's performance is limited, we may need to scale out a little bit. To do this I added an Elastic Loadbalancer to distribute the load about different processes. Actually I cheated a little bit, because I just started several instances of the same program, where each is listening to a different port.

This image shows how the load is distributed about the processes with using the round robin algorithm.
<!-- Hier Bild zur Architektur: ELB einfügen -->
![This is an image](/images/elb.png "Visualization of the elastic load balancer architecture")

The webservers are all listening on different ports (i.e 10000-10005). For this kind of load balancing I used an [application load balancer](https://aws.amazon.com/elasticloadbalancing/features/#Product_comparisons) as AWS mentions you can use it to distribute http(s) connections to multiple ports on the same instance. This is a really great feature, because with this we can build the setup like in the picture above.

This enables us to spread the load over 5 different instances of the same service which are all answering requests. Only the port has to be changed and as I'm a lazy engineer I did this by adding a commandline parameter:

```Go
func main() {
    // Port flag
	portPtr := flag.Int("port", 10000, "Port for the webserver to start")
	flag.Parse()

	initSetup()
	handleRequests(*portPtr)
}
```

The default port is still tcp port 10000, but you can of course enter any other port. You can find the full source code [available here on github](https://github.com/pgrunm/EB-Homework/blob/ports/api.go). The rest is still the same.

This leads us to the performance results I measured for this architecture:

| Number of users | # requests | # failures | Median responsetime | Average response time | Requests/s | Requests Failed/s |
| --------------- | ---------- | ---------- | ------------------- | --------------------- | ---------- | ----------------- |
| 50              | 826        | 0          | 14                  | 16                    | 4,6        | 0                 |
| 100             | 1648       | 0          | 14                  | 16                    | 9,18       | 0                 |
| 200             | 3271       | 0          | 14                  | 15                    | 18,22      | 0                 |
| 400             | 6504       | 0          | 14                  | 16                    | 36,21      | 0                 |
| 800             | 12706      | 0          | 14                  | 16                    | 70,72      | 0                 |
| 1500            | 22829      | 0          | 14                  | 19                    | 126,85     | 0                 |

Not only the number of answered requests increased also number of failures and the average response went down. There were no failures anymore. As you can see scaling out is a very effective strategy to increase the performance of your services.

### Scaling it to the maximum with serverless functions

Now I wanted to scale out my little application to the limit with serverless functions and AWS lambda. [Lambda](https://aws.amazon.com/lambda/features/) enables you to run just the code you need by passing it to AWS. In my case I used Lambda with an API gateway where you would just call an url and this would trigger the Lambda function.

The architecture changed like shown in this diagram:
<!-- Hier Bild zur Architektur: ELB einfügen -->
![This is an image](/images/lambda.png "Visualization of the elastic load balancer architecture")

The length of the source code decreased heavily and looks now like this:

```Go
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/bradfitz/gomemcache/memcache"
	_ "github.com/go-sql-driver/mysql"
)

var (
	db  *sql.DB
	err error

	// Memcached variable
	mc = *memcache.New("hausarbeit-eb-memcached.dldis0.cfg.euc1.cache.amazonaws.com:11211")
)

// Customer - struct for customer data
type Customer struct {
	ID        int    `json:"Id"`
	Surname   string `json:"Surname"`
	Givenname string `json:"Givenname"`
}

// Readings - struct for read data
type Readings struct {
	MeasureID    int    `json:"MeasureID"`
	MeasureDate  string `json:"MeasureDate"`
	MeasureValue int    `json:"MeasureValue"`
}

type myReadings struct {
	Measures []Readings
}

func (reading *myReadings) AddItem(item Readings) {
	reading.Measures = append(reading.Measures, item)
}

func clientError(status int) (events.APIGatewayProxyResponse, error) {
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Body:       http.StatusText(status),
	}, nil
}

func returnCustomerData(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// ID may only contain numbers
	var idRegExp = regexp.MustCompile(`[0-9]`)

	// Parse the id from the query string
	ID := req.QueryStringParameters["id"]

	// Check if the provided ID is valid
	if !idRegExp.MatchString(ID) {
		return clientError(http.StatusBadRequest)
	}
	key := fmt.Sprintf("customerReadings_id_%s", ID)

	it, memErr := mc.Get(key)
	if memErr != nil {
		fmt.Printf("No data for customer id %s in memcached: %s", ID, memErr)

		// Create a db connection
		initSetup()

		// Prepare statement for reading data
		stmtOut, dbErr := db.Prepare("SELECT Measure_ID, Measure_Date, Value FROM Readings WHERE Customers_ID_FK = ?;")
		if dbErr != nil {
			fmt.Println("Error while creating the sql statement")
		}
		defer stmtOut.Close()

		// Query the customer id store it in customerdata
		rows, dbErr := stmtOut.Query(ID)
		defer rows.Close()

		customReadingsList := myReadings{}
		var customerReadings Readings

		if dbErr != nil {
			fmt.Println("unable to query user data", ID, dbErr)
		} else {
			for rows.Next() {

				err := rows.Scan(&customerReadings.MeasureID, &customerReadings.MeasureDate, &customerReadings.MeasureValue)
				if err != nil {
					log.Fatal(err)
				}
				customReadingsList.AddItem(customerReadings)
			}
			json, err := json.Marshal(customReadingsList)
			if err != nil {
				return events.APIGatewayProxyResponse{
					StatusCode: http.StatusOK,
					Body:       string(json),
				}, nil
			}
		}
	}

	// Return the events and a http 200 code.
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Body:       string(it.Value),
	}, nil

}

func initSetup() {

	db, err = sql.Open("mysql", "admin:admin@tcp(123.4.5.6)/example")
	if err != nil {
		panic(err.Error())
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		panic(err.Error())
	} else {
		fmt.Println("DB connection established!")
	}

}

func main() {
	// Start the Lambda Handler
	lambda.Start(returnCustomerData)
}

```

As you can see I'm now parsing the id which is submitted as parameter with a regular expression. If it's valid the programm tries to get the data from the cache. If there is no data inside the cache it queries the database.

Now finally the results fo the lambda performance tests:
<!-- Table with Lambda data -->
| Number of users | # requests | # failures | Median responsetime | Average response time | Requests/s | Requests Failed/s |
| --------------- | ---------- | ---------- | ------------------- | --------------------- | ---------- | ----------------- |
| 50              | 818        | 0          | 27                  | 31                    | 4,56       | 0                 |
| 100             | 1652       | 0          | 27                  | 31                    | 9,2        | 0                 |
| 200             | 3273       | 0          | 27                  | 31                    | 18,2       | 0                 |
| 400             | 6504       | 0          | 26                  | 31                    | 36,14      | 0                 |
| 800             | 12701      | 0          | 27                  | 33                    | 70,41      | 0                 |
| 1500            | 22898      | 0          | 27                  | 36                    | 126,19     | 0                 |

Like in the previous table there are no failures at all. The number of responses is also almost the same. The average response time increased a little bit in comparison with the previous architecture.

## Summary

In the end I can say it's the best to use an Elastic Load Balancer to be able to distribute the load across different nodes or at least different ports on the same node. Using an ELB is a good idea, because you don't have to change the endpoint your users are calling. If there would be no ELB you probably would have to move the dns name of your endpoint (like **www**.example.org to an ELB).

The ELB and AWS Lambda architecture are almost even up. But if it's about scalability we have to take into account that the ELB architecture is still running on only one EC2 instance. This means the machine's capacity isn't endless and at some point you can't scale this architecture anymore.

The Lambda architecture instead scales automatically as load increases. On the other hand the Lambda architecture is harder to set up and to debug. But you'll get an almost infinitely scalable piece of architecture from this. It's up to you to decide what fits better.

I hope you enjoyed my article, feel free to contact me if you have any feedback or suggestions.
