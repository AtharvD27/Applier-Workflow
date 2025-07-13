#!/usr/bin/env bash
set -euo pipefail

# Move into the Terraform folder
cd "$(dirname "$0")"

# Configuration
REGION="us-east-1"
DUMMY_INSTANCE="i-06aed8d8baa0db506"

echo "[→] Initializing Terraform"
terraform init -input=false -no-color

# Fetch the Spot VM's instance ID from state
VM_ID=$(terraform output -raw instance_id)
echo "[→] Will destroy instance: ${VM_ID}"

# Look up the EIP allocation ID attached to that instance
EIP_ALLOC=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --filters "Name=instance-id,Values=${VM_ID}" \
  --query 'Addresses[0].AllocationId' \
  --output text)
echo "[→] Found EIP allocation: ${EIP_ALLOC}"

# Destroy the Terraform-managed infrastructure
echo "[→] Running terraform destroy"
terraform destroy -auto-approve -no-color

# Re-associate the EIP to your dummy instance
echo "[→] Re-attaching EIP to dummy instance ${DUMMY_INSTANCE}"
aws ec2 associate-address \
  --region "$REGION" \
  --instance-id "$DUMMY_INSTANCE" \
  --allocation-id "$EIP_ALLOC"

echo "[✓] Destroy complete; EIP returned to ${DUMMY_INSTANCE}"
