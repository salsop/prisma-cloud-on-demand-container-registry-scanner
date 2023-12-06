#!/bin/bash

# Create On Demand Scanner
terraform apply -auto-approve

# Wait 5 Minutes for On-Demand Scan to Complete
sleep 120

# Destroy On Demand Scanner
terraform destroy -auto-approve
