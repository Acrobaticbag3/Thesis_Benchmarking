package main

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
)

#Deployment: appsv1.#Deployment & {
	#config: #Config

	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      #config.metadata.name
		namespace: #config.metadata.namespace
		labels: app: #config.metadata.name
	}
	spec: {
		replicas: #config.replicas
		selector: matchLabels: app: #config.metadata.name
		template: {
			metadata: labels: app: #config.metadata.name
			spec: containers: [{
				name:            "test-app"
				image:           "\( #config.image.repository ):\( #config.image.tag )"
				imagePullPolicy: corev1.#PullPolicy & #config.image.pullPolicy
				ports: [{
					containerPort: 80
				}]
				resources: {
					limits: {
						cpu:    #config.resources.limits.cpu
						memory: #config.resources.limits.memory
					}
					requests: {
						cpu:    #config.resources.requests.cpu
						memory: #config.resources.requests.memory
					}
				}
			}]
		}
	}
}

#Service: corev1.#Service & {
	#config: #Config

	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      #config.metadata.name
		namespace: #config.metadata.namespace
	}
	spec: {
		selector: app: #config.metadata.name
		ports: [{
			port:       80
			targetPort: 80
		}]
	}
}
