



docker build -t gingersociety/tekton-task-ginger-auth:latest --platform=linux/amd64 -f ginger-auth.Dockerfile .
docker push gingersociety/tekton-task-ginger-auth:latest

docker build -t gingersociety/tekton-task-ginger-infra:latest --platform=linux/amd64 -f ginger-infra.Dockerfile .
docker push gingersociety/tekton-task-ginger-infra:latest

docker build -t gingersociety/tekton-task-ginger-connector-and-db:latest --platform=linux/amd64 -f ginger-connector-and-db.Dockerfile .
docker push gingersociety/tekton-task-ginger-connector-and-db:latest

docker build -t gingersociety/tekton-task-buildah:latest --platform=linux/amd64 -f enhanced-buildah.Dockerfile . --no-cache
docker push gingersociety/tekton-task-buildah:latest

docker build -t gingersociety/tekton-task-gitter:latest --platform=linux/amd64 -f gitter.Dockerfile .
docker push gingersociety/tekton-task-gitter:latest


docker build --progress=plain -t gingersociety/k8-controller-and-runner-base:latest --platform=linux/amd64 -f k8-controller-and-runner.Dockerfile .
docker push gingersociety/k8-controller-and-runner-base:latest


docker build --progress=plain -t gingersociety/python3:latest --platform=linux/amd64 -f python3.Dockerfile .

docker push gingersociety/python3:latest


docker build --progress=plain -t gingersociety/py-lib-base:latest --platform=linux/amd64 -f py-lib-base.Dockerfile .

docker push gingersociety/py-lib-base:latest



