

ginger-infra install-tekton-crd \
  --image docker.gingersociety.org/ginger-society/remote-task-controller:latest \
  --sidekick-url https://api.gingersociety.org/external-executor/run-job


# CRD is registered
kubectl get crd remotetasks.gingersociety.org

# Controller is running in tekton-pipelines namespace
kubectl -n tekton-pipelines get deployment remote-task-controller
kubectl -n tekton-pipelines get pods -l app=remote-task-controller
kubectl -n tekton-pipelines logs -l app=remote-task-controller --follow

  