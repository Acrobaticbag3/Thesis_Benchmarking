package main

#Config: {
	metadata: {
		name:      *"timoni-test-app" | string
		namespace: *"test-namespace" | string
	}
	replicas: *4 | int
	image: {
		repository: *"nginx" | string
		tag:        *"latest" | string
		pullPolicy: *"IfNotPresent" | string
	}
	resources: {
		limits: {
			cpu:    *"1000m" | string
			memory: *"1Gi" | string
		}
		requests: {
			cpu:    *"200m" | string
			memory: *"256Mi" | string
		}
	}
}
