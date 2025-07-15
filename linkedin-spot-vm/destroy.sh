#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"               # → terraform folder

REGION="us-east-1"
DUMMY_INSTANCE="i-06aed8d8baa0db506"
BROWSER_VOLUME_ID="vol-06834ddf3f58d41a8"

echo "[Terraform] init"
terraform init -input=false -no-color

# ------------------------------------------------------------
# Safe instance-ID extraction
# ------------------------------------------------------------
VM_ID=$(terraform output -raw instance_id 2>&1 | grep -oE 'i-[0-9a-f]+' | head -n1)

if [[ -z "$VM_ID" ]]; then
  echo "[ERROR] Could not read instance_id from state" >&2
  exit 1
fi
echo "[Info] Spot instance ID → $VM_ID"

# ------------------------------------------------------------
# Get the Elastic-IP allocation attached to that instance
# ------------------------------------------------------------
EIP_ALLOC=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --filters "Name=instance-id,Values=${VM_ID}" \
  --query 'Addresses[0].AllocationId' \
  --output text)
echo "[Info] EIP allocation   → $EIP_ALLOC"

# ------------------------------------------------------------
# Detach browser volume before destroying instance
# ------------------------------------------------------------
echo "[Info] Detaching browser volume from instance..."
aws ec2 detach-volume \
  --region "$REGION" \
  --volume-id "$BROWSER_VOLUME_ID" \
  --instance-id "$VM_ID" \
  --force || echo "[Warning] Browser volume might not be attached"

# Wait for volume to detach
echo "[Info] Waiting for browser volume to detach..."
sleep 30

# ------------------------------------------------------------
# Destroy the Terraform-managed resources
# ------------------------------------------------------------
echo "[Terraform] destroy"
terraform destroy -auto-approve -no-color

# ------------------------------------------------------------
# Re-associate EIP to dummy instance
# ------------------------------------------------------------
echo "[AWS] Reattaching EIP to dummy instance: $DUMMY_INSTANCE"
aws ec2 associate-address \
  --region "$REGION" \
  --instance-id "$DUMMY_INSTANCE" \
  --allocation-id "$EIP_ALLOC"

echo "[✓] Destroy complete; EIP returned to $DUMMY_INSTANCE"
echo "[✓] Browser volume $BROWSER_VOLUME_ID preserved and available for reuse"