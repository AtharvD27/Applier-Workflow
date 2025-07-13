#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"          # enter terraform folder

REGION="us-east-1"
DUMMY_INSTANCE="i-06aed8d8baa0db506"

echo "[Terraform] init"
terraform init -input=false -no-color

# ------------------------------------------------------------
# Grab instance-ID safely, strip any trailing CR/LF characters
# ------------------------------------------------------------
VM_ID=$(terraform output -raw instance_id | tr -d '\r\n')
echo "[Info] Spot instance ID  →  ${VM_ID}"

# ------------------------------------------------------------
# Find the EIP allocation that is attached to that instance
# ------------------------------------------------------------
EIP_ALLOC=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --filters "Name=instance-id,Values=${VM_ID}" \
  --query 'Addresses[0].AllocationId' \
  --output text)
echo "[Info] EIP allocation ID →  ${EIP_ALLOC}"

# ------------------------------------------------------------
# Destroy VM + related resources
# ------------------------------------------------------------
echo "[Terraform] destroy"
terraform destroy -auto-approve -no-color

# ------------------------------------------------------------
# Hand the Elastic IP back to dummy instance
# ------------------------------------------------------------
echo "[AWS] Re-attaching EIP to dummy instance ${DUMMY_INSTANCE}"
aws ec2 associate-address \
  --region "$REGION" \
  --instance-id "$DUMMY_INSTANCE" \
  --allocation-id "$EIP_ALLOC"

echo "[✓] Cleanup finished."
