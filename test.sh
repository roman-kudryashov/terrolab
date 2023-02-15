#!/bin/bash
REGION="us-east-1"
LB="lb-terraform-lab-ghost-alb"
LBARN=$(aws elbv2 describe-load-balancers --region $REGION --names $LB | jq -r '.LoadBalancers[].LoadBalancerArn')
for i in $(aws elbv2 describe-target-groups --load-balancer-arn $LBARN --region $REGION | jq -r '.TargetGroups[].TargetGroupArn');do \
aws elbv2 describe-target-health --target-group-arn $i --region $REGION; \
done
