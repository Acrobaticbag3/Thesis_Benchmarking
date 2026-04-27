#!bin/bash
helm upgrade --install --test-app . \
    --namespace test-namespace \
    --wait