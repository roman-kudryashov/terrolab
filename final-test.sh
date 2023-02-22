#!/bin/bash

REGION=us-east-1
LB="arn:aws:elasticloadbalancing:us-east-1:294360715377:loadbalancer/app/lb-terraform-lab-ghost-alb/57b40bd62720d112"
for i in $(aws elbv2 describe-target-groups --load-balancer-arn $LB --region $REGION | jq -r '.TargetGroups[].TargetGroupArn');
do aws elbv2 describe-target-health --target-group-arn $i --region $REGION;
done