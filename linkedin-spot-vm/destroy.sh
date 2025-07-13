#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"        # always operate inside linkedin-spot-vm/

REGION="us-east-1"
DUMMY_INSTANCE="i-06aed8d8baa0db506"

echo "[Terraform] init"
terraform init -input=false -no-color

# ------------------ Get the EC2 instance ID from state ------------------
VM_ID=$(terraform output -raw instance_id 2>/dev/null || true)

if [[ -z "$VM_ID" || "$VM_ID" == "null" ]]; then
  echo "[Info] No instance_id found in state. Nothing to destroy."
  exit 0
fi
echo "[Info] Instance to destroy: $VM_ID"

# ------------------ Look up the EIP Allocation ID ------------------
EIP_ALLOC=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --filters "Name=instance-id,Values=$VM_ID" \
  --query 'Addresses[0].AllocationId' \
  --output text)

echo "[Info] EIP allocation-id: $EIP_ALLOC"

# ------------------ Destroy all Terraform-managed resources ------------------
echo "[Terraform] destroy"
terraform destroy -auto-approve -no-color

# ------------------ Hand the EIP back to the dummy t2.micro ------------------
echo "[AWS] Re-associate $EIP_ALLOC to $DUMMY_INSTANCE"
aws ec2 associate-address \
  --region "$REGION" \
  --instance-id "$DUMMY_INSTANCE" \
  --allocation-id "$EIP_ALLOC"

echo "[✓] Destroy complete; EIP returned to dummy instance."
