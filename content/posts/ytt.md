---
title: "Kubernetes templating with Carvel ytt"
date: 2023-07-25T13:35:33+02:00
draft: false
tags: [kubernetes, yaml, cncf]
---

## Introduction

Hello again, this is another blog post about a great CNCF tool. If you've ever worked with Kubernetes manifests, you probably know that editing or creating them by hand can be very painful.

On the other side, you as a developer or engineer don't want to edit a lot in these manifests. It is usually better to edit the necessary parts and leave the rest as it was before.

But how do you manage deployments on a bigger scale? Image for many teams with different services and requirements? Every developer would need knowledge for the manifest files.

## The solution

One way to solve this is abstraction. You just enable your developers to fill out only the necessary fields and the rest is automatically generated.

According to the [GitOps principles](https://github.com/open-gitops/documents/blob/v1.0.0/PRINCIPLES.md), the desired state of systems should be

- Declarative
- Versioned and immutable
- Pulled automatically and
- Continuously Reconciled.

This can be achieved by using templates. One really great CNCF tool is [Carvel ytt](https://carvel.dev/ytt/). ytt is not only a commandline tool, which allows you to render the templates locally but also in a CI/CD way. Even better, it comes with a local playground, which allows you to play around and test, before you break anything inside the templating.

### Preparing the required data

I'm starting with a simple example: Image you want to deploy a Prometheus exporter inside of Kubernetes. ytt uses [Starlark](https://github.com/bazelbuild/starlark) as a Python based programming language. With this language, you can create powerful templating mechanisms.

You start by creating a simple values file, with all necessary but basic settings, which looks like this:

```yaml
#@data/values
---
app_name: example-exporter
prioritiy_class: low
metrics:
  scrape: true
  port: 9100
  path: /metrics
labels:
  team: devops
resources:
  mem_limit: 32Mi
  mem_requests: 16Mi
  cpu_limit: 0.01
stages:
  - name: dev
    namespace: dev
    variables:
      database: dev.example.com
    replicas: 1
    version: 0.2
  - name: qa
    namespace: qa
    variables:
      database: qa.example.com
    replicas: 1
    version: 0.2
  - name: prod
    namespace: prod
    variables:
      database: prod.example.com
    replicas: 1
    version: 0.2
```

This file contains all the necessary data, to finally create all Kubernetes objects like

- different deployments per stage (dev, qa and prod) and the namespace
- a service per stage
- labels
- number of replicas
- resource limits
- a priority class and
- annotations for metrics scraping with Prometheus

### Creating the Kubernetes manifest templates

The next step is to create the actual Kubernetes manifests for templating. We start with the service object which looks like this:

```yaml
#@ load("@ytt:data", "data")

#@ for item in data.values.stages:
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: #@ data.values.app_name
    team: #@ data.values.labels.team
  name: #@ data.values.app_name
  namespace: #@ item.namespace
spec:
  ports:
    - name: http
      port: 9100
      protocol: TCP
      targetPort: 9100
  selector:
    app: #@ data.values.app_name
#@ end
```

You can save this file into a directory, which is called `deployment`. The next step is to create the actual deployment manifest template:

```yaml
#@ load("@ytt:data", "data")

#@ for item in data.values.stages:
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: #@ data.values.app_name
    team: #@ data.values.labels.team
  name: #@ data.values.app_name
  namespace: #@ item.namespace
spec:
  replicas: #@ item.replicas
  selector:
    matchLabels:
      app: #@ data.values.app_name
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: #@ data.values.app_name
      annotations:
        "prometheus.io/scrape": "true"
        "prometheus.io/port": #@ data.values.metrics.port
    spec:
      containers:
        image: #@ "ghcr.io/example-org/" +  data.values.app_name + ":" + str(item.version)
        env:
        - name: DATABASE
            value: #@ item.variables.db
        imagePullPolicy: Always
        livenessProbe:
        failureThreshold: 3
        httpGet:
            path: #@ data.values.metrics.path
            port: #@ data.values.metrics.port
        periodSeconds: 10
        name: #@ data.values.app_name
        ports:
        - containerPort: #@ data.values.metrics.port
            name: http
        readinessProbe:
        httpGet:
            path: #@ data.values.metrics.path
            port: #@ data.values.metrics.port
        periodSeconds: 5
        resources:
        limits:
            memory: #@ data.values.resources.mem_limit
            cpu: #@ data.values.resources.cpu_limit
        requests:
            memory: #@ data.values.resources.mem_requests
      priorityClassName: #@ data.values.prioritiy_class
      restartPolicy: Always
#@ end
```

### Using variables with ytt

As you saw, we used a lot of YAML comments within the code. But these of course aren't comments, these are variables for ytt! If you look at the metadata part, you can see these are all variables:

```yaml
metadata:
  labels:
    app: #@ data.values.app_name
    team: #@ data.values.labels.team
  name: #@ data.values.app_name
  namespace: #@ item.namespace
```

Even better: We're creating a manifest per **stage**! This means, whenever we create a new stage inside the values file, the deployment manifests will be created automatically for us.

## Putting it all together

Once everyone of the two above listed files is prepared, we can create the manifest file. This couldn't be simpler as running the command `ytt -f deployment -f values.yaml > deployment.autogen.yaml`.

The finally generated manifest for the prod stage looks like this:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: example-exporter
    team: devops
  name: example-exporter
  namespace: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example-exporter
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: example-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: 9100
    spec:
      containers:
        image: ghcr.io/example-org/example-exporter:0.2
        env:
        - name: DATABASE
          value: prod.example.com
        imagePullPolicy: Always
        livenessProbe: null
        failureThreshold: 3
        httpGet:
          path: /metrics
          port: 9100
        periodSeconds: 10
        name: example-exporter
        ports:
        - containerPort: 9100
          name: http
        readinessProbe:
          httpGet:
            path: /metrics
            port: 9100
          periodSeconds: 5
        resources: null
        limits:
          memory: 32Mi
          cpu: 0.01
        requests:
          memory: 16Mi
      priorityClassName: low
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: example-exporter
    team: devops
  name: example-exporter
  namespace: prod
spec:
  ports:
  - name: http
    port: 9100
    protocol: TCP
    targetPort: 9100
  selector:
    app: example-exporter

```

And this all comes out from just a single command and a little templating. Every time we change something inside the values file, we can recreate the resulting manifest or even better, render this with a CI/CD setup.

If you pair this with a [Taskfile](https://taskfile.dev/) you can watch for any changes, to automatically render the new manifests.

## Conclusion

ytt is a great tool for abstraction, which enables DevOps engineers and developers to automate a lot of their Kubernetes work. If you pair this powerful tool with CI/CD you can easily speed up your deployments, while lowering the entry burden for new developers.
