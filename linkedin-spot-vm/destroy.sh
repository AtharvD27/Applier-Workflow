#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

DUMMY_INSTANCE="i-06aed8d8baa0db506"
REGION="us-east-1"

echo "[Terraform] init → destroy"
terraform init -input=false -no-color
VM_ID=$(terraform output -raw instance_id)
EIP_ALLOC=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --filters Name=instance-id,Values="$VM_ID" \
  --query 'Addresses[0].AllocationId' \
  --output text)

terraform destroy -auto-approve -no-color

echo "[AWS] Reattaching $EIP_ALLOC to $DUMMY_INSTANCE"
aws ec2 associate-address                    \
  --instance-id "$DUMMY_INSTANCE"            \
  --allocation-id "$EIP_ALLOC"               \
  --region "$REGION"
