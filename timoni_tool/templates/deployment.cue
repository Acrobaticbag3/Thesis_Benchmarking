package main

#Config: {
	metadata: {
		name:      *"timoni-test-app" | string
		namespace: *"test-namespace" | string
	}
	replicas: *4 | int & >=1
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

config: #Config

deployment: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      config.metadata.name
		namespace: config.metadata.namespace
		labels: app: config.metadata.name
	}
	spec: {
		replicas: config.replicas
		selector: matchLabels: app: config.metadata.name
		template: {
			metadata: labels: app: config.metadata.name
			spec: containers: [{
				name:            "test-app"
				image:           "\(config.image.repository):\(config.image.tag)"
				imagePullPolicy: config.image.pullPolicy
				ports: [{containerPort: 80}]
				resources: {
					limits: {
						cpu:    config.resources.limits.cpu
						memory: config.resources.limits.memory
					}
					requests: {
						cpu:    config.resources.requests.cpu
						memory: config.resources.requests.memory
					}
				}
			}]
		}
	}
}

service: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      config.metadata.name
		namespace: config.metadata.namespace
	}
	spec: {
		selector: app: config.metadata.name
		ports: [{
			port:       80
			targetPort: 80
		}]
	}
}
