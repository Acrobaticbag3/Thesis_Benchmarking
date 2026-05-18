package main

import (
	"timoni.sh/core/v1alpha1"
)

#Instance: {
	config: #Config
	objects: {
		deployment: #Deployment & {
			#config: config
		}
		service: #Service & {
			#config: config
		}
	}
}
