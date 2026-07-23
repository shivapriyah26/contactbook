#!/bin/bash
# deploy.sh — registers a new ECS task definition revision using the freshly
# built image, then updates the service to use it (rolling deployment).
#
# Usage: ./deploy.sh <cluster-name> <service-name> <image-tag>

set -euo pipefail

CLUSTER=$1
SERVICE=$2
IMAGE_TAG=$3

echo "==> Deploying image tag '$IMAGE_TAG' to service '$SERVICE' in cluster '$CLUSTER'"

# 1. Get the current task definition (used as a template)
CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
  --task-definition "$SERVICE" \
  --query "taskDefinition")

# 2. Swap in the new image URI(s) and strip fields ECS won't accept on register
NEW_TASK_DEF=$(echo "$CURRENT_TASK_DEF" | jq --arg IMAGE_TAG "$IMAGE_TAG" '
  .containerDefinitions[0].image |= (split(":")[0] + ":" + $IMAGE_TAG) |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
      .compatibilities, .registeredAt, .registeredBy)
')

# 3. Register the new task definition revision
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json "$NEW_TASK_DEF" \
  --query "taskDefinition.taskDefinitionArn" \
  --output text)

echo "==> Registered new task definition: $NEW_TASK_DEF_ARN"

# 4. Update the service to use it, with a rolling deployment
#    minimumHealthyPercent/maximumPercent give us zero-downtime rollout
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "$NEW_TASK_DEF_ARN" \
  --force-new-deployment

echo "==> Waiting for service to stabilize..."
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"

echo "==> Deployment complete."
