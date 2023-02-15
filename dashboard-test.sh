DASHBOARD="terralab"
REGION="us-east-1"
aws cloudwatch get-dashboard --dashboard-name $DASHBOARD --region $REGION | jq -c '.DashboardBody | fromjson' | jq '.widgets[] | [.properties.title, .type]'