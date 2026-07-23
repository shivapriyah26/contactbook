#!/bin/bash
# rollback.sh — reverts an ECS service to a known-good task definition.
#
# Usage:
#   ./rollback.sh <cluster-name> <service-name> [previous-task-def-arn]
#
# If previous-task-def-arn is omitted, the script looks up the second-to-last
# ACTIVE revision of the service's task family and rolls back to that.

set -euo pipefail

CLUSTER=$1
SERVICE=$2
PREVIOUS_TASK_DEF=${3:-}

echo "==> Rolling back service '$SERVICE' in cluster '$CLUSTER'"

if [ -z "$PREVIOUS_TASK_DEF" ]; then
  FAMILY=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
    --query "services[0].taskDefinition" --output text | sed -E 's#.*/([^:]+):.*#\1#')

  PREVIOUS_TASK_DEF=$(aws ecs list-task-definitions \
    --family-prefix "$FAMILY" \
    --status ACTIVE \
    --sort DESC \
    --query "taskDefinitionArns[1]" \
    --output text)
fi

echo "==> Reverting to task definition: $PREVIOUS_TASK_DEF"

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "$PREVIOUS_TASK_DEF" \
  --force-new-deployment

echo "==> Waiting for rollback to stabilize..."
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"

echo "==> Rollback complete. Service is back on the previous stable version."
