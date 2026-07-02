kubectl create configmap grafana-dashboard-infra \
  --from-file=infra-overview.json=infra-overview.json \
  --from-file=infra-live-values.json=infra-live-values.json \
  --dry-run=client -o yaml | kubectl apply -f -