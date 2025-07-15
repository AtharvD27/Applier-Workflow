#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"               # → terraform folder

REGION="us-east-1"
DUMMY_INSTANCE="i-06aed8d8baa0db506"
BROWSER_VOLUME_ID="vol-06834ddf3f58d41a8"

echo "[INFO] Starting LinkedIn Spot VM destruction process..."

echo "[Terraform] Initializing..."
terraform init -input=false -no-color

# ------------------------------------------------------------
# Safe instance-ID extraction
# ------------------------------------------------------------
VM_ID=$(terraform output -raw instance_id 2>&1 | grep -oE 'i-[0-9a-f]+' | head -n1)

if [[ -z "$VM_ID" ]]; then
  echo "[ERROR] Could not read instance_id from Terraform state" >&2
  echo "[INFO] Checking if state file exists..."
  if [[ ! -f "terraform.tfstate" ]]; then
    echo "[WARNING] No terraform.tfstate file found. Instance may already be destroyed."
    exit 0
  fi
  echo "[ERROR] State file exists but instance_id not found. Manual cleanup may be required." >&2
  exit 1
fi
echo "[INFO] Spot instance ID → $VM_ID"

# ------------------------------------------------------------
# Get the Elastic-IP allocation attached to that instance
# ------------------------------------------------------------
echo "[INFO] Retrieving EIP allocation..."
EIP_ALLOC=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --filters "Name=instance-id,Values=${VM_ID}" \
  --query 'Addresses[0].AllocationId' \
  --output text 2>/dev/null || echo "None")

if [[ "$EIP_ALLOC" != "None" && "$EIP_ALLOC" != "null" ]]; then
  echo "[INFO] EIP allocation found → $EIP_ALLOC"
else
  echo "[WARNING] No EIP found attached to instance $VM_ID"
  EIP_ALLOC=""
fi

# ------------------------------------------------------------
# Safely detach browser volume before destroying instance
# ------------------------------------------------------------
echo "[INFO] Checking browser volume attachment..."
VOLUME_ATTACHED=$(aws ec2 describe-volumes \
  --region "$REGION" \
  --volume-ids "$BROWSER_VOLUME_ID" \
  --query 'Volumes[0].Attachments[?InstanceId==`'$VM_ID'`].State' \
  --output text 2>/dev/null || echo "")

if [[ -n "$VOLUME_ATTACHED" && "$VOLUME_ATTACHED" != "None" ]]; then
  echo "[INFO] Browser volume is attached to instance. Detaching..."
  aws ec2 detach-volume \
    --region "$REGION" \
    --volume-id "$BROWSER_VOLUME_ID" \
    --instance-id "$VM_ID" \
    --force || echo "[WARNING] Failed to detach volume, but continuing..."
  
  # Wait for volume to detach
  echo "[INFO] Waiting for browser volume to detach (max 60 seconds)..."
  for i in {1..12}; do
    VOLUME_STATE=$(aws ec2 describe-volumes \
      --region "$REGION" \
      --volume-ids "$BROWSER_VOLUME_ID" \
      --query 'Volumes[0].State' \
      --output text 2>/dev/null || echo "unknown")
    
    if [[ "$VOLUME_STATE" == "available" ]]; then
      echo "[INFO] ✅ Browser volume successfully detached"
      break
    fi
    
    echo "[INFO] Volume state: $VOLUME_STATE, waiting... ($i/12)"
    sleep 5
  done
else
  echo "[INFO] Browser volume not attached to this instance or already detached"
fi

# ------------------------------------------------------------
# Destroy the Terraform-managed resources
# ------------------------------------------------------------
echo "[Terraform] Destroying infrastructure..."
if terraform destroy -auto-approve -no-color; then
  echo "[INFO] ✅ Terraform destroy completed successfully"
else
  echo "[ERROR] Terraform destroy failed, but continuing with EIP reattachment..." >&2
fi

# ------------------------------------------------------------
# Re-associate EIP to dummy instance (if we found one)
# ------------------------------------------------------------
if [[ -n "$EIP_ALLOC" ]]; then
  echo "[AWS] Reattaching EIP to dummy instance: $DUMMY_INSTANCE"
  if aws ec2 associate-address \
    --region "$REGION" \
    --instance-id "$DUMMY_INSTANCE" \
    --allocation-id "$EIP_ALLOC" 2>/dev/null; then
    echo "[INFO] ✅ EIP successfully returned to dummy instance"
  else
    echo "[WARNING] Failed to reattach EIP to dummy instance. Manual intervention may be required." >&2
  fi
else
  echo "[INFO] No EIP to reattach"
fi

# ------------------------------------------------------------
# Verify browser volume is available for future use
# ------------------------------------------------------------
echo "[INFO] Verifying browser volume status..."
FINAL_VOLUME_STATE=$(aws ec2 describe-volumes \
  --region "$REGION" \
  --volume-ids "$BROWSER_VOLUME_ID" \
  --query 'Volumes[0].State' \
  --output text 2>/dev/null || echo "unknown")

if [[ "$FINAL_VOLUME_STATE" == "available" ]]; then
  echo "[INFO] ✅ Browser volume $BROWSER_VOLUME_ID is available for reuse"
  echo "[INFO] Volume contains: Gmail login, Drive folder, optimized browser scripts"
else
  echo "[WARNING] Browser volume state: $FINAL_VOLUME_STATE"
fi

echo ""
echo "🎉 [SUCCESS] Destruction process completed!"
echo "📋 Summary:"
echo "   • Spot instance $VM_ID terminated"
if [[ -n "$EIP_ALLOC" ]]; then
  echo "   • EIP returned to dummy instance $DUMMY_INSTANCE"
fi
echo "   • Browser volume $BROWSER_VOLUME_ID preserved and ready for reuse"
echo "   • All browser data, logins, and scripts are safe on the EBS volume"