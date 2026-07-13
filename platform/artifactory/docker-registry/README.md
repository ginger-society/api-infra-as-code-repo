
# dry run
registry garbage-collect --dry-run --delete-untagged /etc/docker/registry/config.yml


# scale down registry
kubectl scale deployment registry --replicas=0

# wait for it to stop
kubectl get pods -w | grep registry

# exec into a temporary registry pod to run GC
kubectl run registry-gc --rm -it \
  --image=registry:2 \
  --overrides='{"spec":{"volumes":[{"name":"registry-storage","persistentVolumeClaim":{"claimName":"registry-pvc"}}],"containers":[{"name":"registry-gc","image":"registry:2","command":["sh"],"stdin":true,"tty":true,"volumeMounts":[{"mountPath":"/var/lib/registry","name":"registry-storage"}]}]}}' \
  -- sh


# Then inside the pod:


registry garbage-collect --delete-untagged /etc/docker/registry/config.yml


# scale back 
kubectl scale deployment registry --replicas=1



find /var/lib/registry/docker/registry/v2/repositories -type d -name _manifests | while read m; do
  repo_dir=$(dirname "$m")
  if [ ! -d "$m/tags" ] || [ -z "$(ls -A "$m/tags" 2>/dev/null)" ]; then
    echo "EMPTY: $repo_dir"
  fi
done


find /var/lib/registry/docker/registry/v2/repositories -type d -name _manifests | while read m; do
  repo_dir=$(dirname "$m")
  if [ ! -d "$m/tags" ] || [ -z "$(ls -A "$m/tags" 2>/dev/null)" ]; then
    echo "Deleting empty repo: $repo_dir"
    rm -rf "$repo_dir"
  fi
done