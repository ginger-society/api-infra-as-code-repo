# This is the repo for API services deployed on api-*.gingersociety.org


## There is only one env as of now : staging

This is deployed on api-staging.gingersociety.org

Common code related to this env is available in staging directory
There are few apps deployed

1. **example-app**

    This is a sample hello world service

    Available on api-staging.gingersociety.org/test/*
2. **iam-service-api**

    This is the deployment for IAM service apis

    Available on api-staging.gingersociety.org/iam/*
3. **metadata-service-api**

    This is the deployment for Metadata service apis

    Available on api-staging.gingersociety.org/metadata/*



## Notes we took while creating this repo

deploy your app and service and map the service in ingress file

https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx


helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f nginx-value.yaml 

then add ignress
kubectl apply -f ingress.yaml


https://artifacthub.io/packages/helm/cert-manager/cert-manager

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.2/cert-manager.crds.yaml

Add the Jetstack Helm repository
$ helm repo add jetstack https://charts.jetstack.io --force-update

helm install cert-manager -n cert-manager --version v1.15.2 jetstack/cert-manager -f cert-manager-values.yaml

then add issuer
kubectl apply -f issuer.yaml

In case of ssl not working , please use : 
```sh
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```


# Rust helpers

```sh
docker build --platform linux/amd64 -t rust-cli-builder:latest -f Dockerfile.build  .

```

while using rust-helpers , please add .env file in your project root with 

```env

AWS_ACCESS_KEY_ID=ID
AWS_SECRET_ACCESS_KEY=ACCESS_TOKEN
AWS_DEFAULT_REGION=region
GINGER_TOKEN=API_TOKEN

```

To use the installed use the following command

```sh
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/installer.sh)" -- ginger-society/ginger-connector:latest
```
To install all the apps ( mac and linux )

```sh
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/main/rust-helpers/install-all-clis.sh)"

```

apart from building x86 imgae of the dev container images , you also need to build arm image if you are building it on mac

```sh
docker build -t gingersociety/vite-react-dev . -f devcontainer-images/vite-react/Dockerfile.dev

```

```sh
docker push gingersociety/vite-react-dev

```


Notes
kubectl port-forward rabbitmq-something 15672:15672
