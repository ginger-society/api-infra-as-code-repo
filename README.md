# Welcome to [Your Company Name] 🎉

Welcome aboard! We're excited to have you join the team as a Full Stack Engineer. This document will walk you through your initial setup and provide an overview of our tech stack, tools, and processes to help you hit the ground running. Let's dive in!

## Table of Contents

1. [Getting Access](#getting-access)
2. [Setting Up Your Development Environment](#setting-up-your-development-environment)
3. [Tech Stack Overview](#tech-stack-overview)
4. [Working with Repositories](#working-with-repositories)
5. [Deployment and Environments](#deployment-and-environments)
6. [Common Tools and Practices](#common-tools-and-practices)
7. [Company Culture and Communication](#company-culture-and-communication)
8. [Additional Resources](#additional-resources)

---

### 1. Getting Access

To get started, you'll need access to the following:

- **GitHub:** Our code is hosted here. Please send your GitHub username to your manager for repo access.
- **Docker Hub:** We use Docker Hub for container images. Share your Docker ID for team access.
- **GCP, AWS, and DigitalOcean:** We use multiple cloud providers, so reach out for access to our resources as needed.
- **Slack (or preferred team communication tool):** For company and team communication.
- **Documentation tools (Confluence, Notion, etc.):** Request access if needed.

---

### 2. Setting Up Your Development Environment

#### 2.1 Clone the Repositories

1. **Clone the main repository** (and any additional ones as directed by your manager).
   ```bash
   git clone https://github.com/[YourCompany]/[MainRepo].git
   ```

2. **Install Dependencies:**
   - **npm:** Run `npm install` where applicable for frontend projects.
   - **Docker:** Pull Docker images or build them locally.

#### 2.2 Set Up Docker

We use Docker extensively for development, staging, and production environments.

- Ensure Docker is installed and running.
- **Pull development images:**
  ```bash
  docker-compose up --build
  ```

#### 2.3 Configure Environment Variables

1. **Environment Files:** Copy `.env.example` to `.env` and update any secrets.
2. **Secrets Management:** We use [GCP Secret Manager/AWS Secrets Manager] (depending on your stack) to securely store and access sensitive information.

---

### 3. Tech Stack Overview

#### Backend

- **Languages:** Rust, Python
- **Database:** PostgreSQL for relational data, Redis for caching
- **Message Broker:** RabbitMQ for queueing
- **Cloud Services:** GCP (primary), AWS (for SES, S3), DigitalOcean (for backup or specific services)

#### Frontend

- **Framework:** ReactJS
- **Package Manager:** npm (pnpm or Yarn if preferred by the team)

#### DevOps

- **Containerization:** Docker
- **CI/CD:** GitHub Actions for automated testing and deployment
- **Orchestration:** Kubernetes for managing our containerized applications

---

### 4. Working with Repositories

We follow a **feature-branch workflow**:

1. **Create a branch** for new features or bug fixes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Push your changes** and open a **Pull Request (PR)** on GitHub.
3. **PR Reviews:** All PRs require at least one review. Make sure your PR includes meaningful commits and messages.

---

### 5. Deployment and Environments

- **Development:** Local environment with Docker and Docker Compose.
- **Staging:** Managed with Kubernetes and deployed to our staging cluster in GCP.
- **Production:** Kubernetes cluster in GCP, with automated deployments via GitHub Actions.

#### Deployment Process

1. Merge changes to the `main` branch for deployment.
2. **CI/CD Pipeline:** GitHub Actions will automatically build, test, and deploy the application to the specified environment.

---

### 6. Common Tools and Practices

#### Docker and Docker Compose

- **Docker Hub:** All public/private images are available at [Your Docker Hub URL].
- Run `docker-compose up` for local development setup.

#### Kubernetes

We use Kubernetes clusters for production and staging environments, with resources managed by Helm charts. You'll need access to `kubectl` to monitor the clusters.

#### Database Management

- **PostgreSQL:** Access databases through [pgAdmin/other preferred tools]. Make sure to follow our migration guidelines when updating schemas.
- **Redis:** Used primarily for caching. Access via CLI or Redis GUI if needed.

#### Message Queues and Email

- **RabbitMQ:** Used for handling async tasks. Use the RabbitMQ dashboard for monitoring.
- **SES:** For email functionality. Credentials are available in your environment configuration.

---

### 7. Company Culture and Communication

- **Daily Standups:** We have quick standups to check in on daily progress and blockers.
- **Slack Channels:** Use specific channels for queries (#frontend, #backend, etc.)
- **Documentation:** Update documentation when you work on new features or processes.

---

### 8. Additional Resources

- **API Documentation:** Refer to [API documentation URL] for REST and GraphQL endpoint details.
- **Code Style Guides:** Refer to our [JavaScript/Rust/Python] guidelines in the repo.
- **Onboarding Checklist:** Complete the onboarding checklist available in [Project Management Tool/Notion].



---- Notes----


kubectl scale statefulset dc01-pg-db-1-postgresql --replicas=1
for installing tekton: 

kubectl apply --filename https://infra.tekton.dev/tekton-releases/pipeline/latest/release.yaml


nginx proxy for the gitloite 
stream {
    server {
        listen 3333;
        proxy_pass 192.168.49.2:31163;
    }

    server {
        listen 5000;
        proxy_pass 192.168.49.2:32638;
        proxy_connect_timeout 10s;
        proxy_timeout 300s;
    }
}
in .ssh/config

Host source.gingersociety.org
    User git
    HostName source.gingersociety.org
    Port 3333
    IdentityFile ~/.ssh/id_ed25519

---- for creating private key inside the secret : 

kubectl create secret generic ssh-private-key --from-file=id_ed25519=runner-private-key



kubectl delete pod --field-selector=status.phase==Failed
kubectl delete pod --field-selector=status.phase==Succeeded


kubectl create secret generic pg-credentials \
  --from-literal=password='your_postgres_password'

kubectl create secret generic aws-creds \
  --from-literal=access_key='your_aws_access_key' \
  --from-literal=secret_key='your_aws_secret_key'


kubectl create secret generic pipeline-secrets-secret   --from-env-file=secrets.env   -n tasks-NAME-provisioner-service


sudo nano /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl reload nginx

kind create cluster --config gingersociety.org

docker update \
  --cpus="2" \
  --memory="2g" \
  NAME-control-plane


set docker host : 
export DOCKER_HOST=unix:///Users/$USER/.docker/run/docker.sock


open current folder in dev container : code --folder-uri="vscode-remote://dev-container+$(pwd | tr -d '\n' | xxd -c 256 -p)/workspaces/$(basename "$(pwd)")"

codium --folder-uri "vscode-remote://ssh-remote+dc0102/home/dc0102"
codium --install-extension ms-python.python

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.allowSnippetAnnotations=true


to allow a folder to have .envrc loaded for new shell session : 

direnv allow

mkdir -p ~/.ginger-society/ssh-keys/NAME

ssh-keygen -t ed25519 -f ~/.ginger-society/ssh-keys/NAME/id_ed25519 -C "NAME"




sudo mkdir -p /var/log/apache2/NAME


sudo chown -R www-data:www-data /var/log/apache2/NAME
sudo chmod 755 /var/log/apache2/NAME


kubectl run tmp-psql --rm -it --image=postgres --restart=Never \
  --env="PGPASSWORD=$(kubectl get secret pg-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)" \
  --command -- psql -h pg-postgresql -U postgres -c "CREATE DATABASE \"ginger-kube-db\";"


------K8 Dashboard ------
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml


  kubectl -n kubernetes-dashboard patch deployment kubernetes-dashboard \
  --type=json \
  -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enable-skip-login"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--token-ttl=0"}
  ]'



  Install tekton using 

kubectl apply --filename https://infra.tekton.dev/tekton-releases/pipeline/latest/release.yaml

Then the dashboard : 

# Install dashboard directly — skip the installer script
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Wait for dashboard
kubectl wait -n tekton-pipelines \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/part-of=tekton-dashboard,app.kubernetes.io/component=dashboard \
  --timeout=90s



echo "/srv/nfs/registry-cache 192.168.49.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo exportfs -v



curl -X POST https://api.gingersociety.org/iam/create-api-session-token \
  -d '{"api_token": "", "days_to_expire": 365}'

# use response to create regcred
kubectl create secret docker-registry regcred \
  --docker-server=docker.gingersociety.org \
  --docker-username=__token__ \
  --docker-password=<long-lived-session-token> \
  -n default

  

sudo sysctl -w fs.inotify.max_user_watches=1048576
sudo sysctl -w fs.inotify.max_user_instances=1024




sh <(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/refs/heads/main/rust-helpers/upload.sh)


 curl -X 'POST' \
  'https://source.gingersociety.org/repo/run-pipeline' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{
  \"branch\": \"main\",
  \"params\": [
    {
      \"key\": \"target_env\",
      \"val\": \"string\"
    },
    {
      \"key\": \"dry_run\",
      \"val\": \"string\"
    },
    {
      \"key\": \"HOSTING_FQDN\",
      \"val\": \"your.domain.com\"
    },
    {
      \"key\": \"vault\",
      \"val\": $(cat vault.json | jq -c . | jq -Rs .)
    },
    {
      \"key\": \"values\",
      \"val\": $(cat values.json | jq -c . | jq -Rs .)
    }
  ],
  \"pipeline_name\": \"debug.yml\",
  \"repo\": \"ginger-society-iac\",
  \"triggered_by\": \"alice\"
}"



sudo bash -c 'cat > /etc/letsencrypt/godaddy.ini << EOF
dns_godaddy_secret = YOUR_API_SECRET
dns_godaddy_key = YOUR_API_KEY
EOF'

sudo chmod 600 /etc/letsencrypt/godaddy.ini



ginger-infra install-tekton-crd \
  --image gingersociety/remote-task-controller:latest \
  --sidekick-url https://api.gingersociety.org/external-executor/run-job \
  --runner-image gingersociety/external-executor-runner:latest

  

  kubectl create secret generic ginger-society-auth \
  --from-literal=auth.json='{"API_TOKEN":""}' \
  -n default


  # Example 1 — via RemoteTask CRD (standalone, no pipeline)
# The controller watches for this and creates a TaskRun automatically.
#
#   kubectl apply -f this-file.yaml
#   kubectl get taskrun example-remote-task -n default
#   kubectl logs -l remotetask=example-remote-task -n default --follow
#
# Prerequisite: auth secret must exist in the same namespace:
#   kubectl create secret generic ginger-society-auth \
#     --from-literal=auth.json='{"API_TOKEN":"<your-token>"}' \
#     -n default
---
apiVersion: gingersociety.org/v1alpha1
kind: RemoteTask
metadata:
  name: example-remote-task
  namespace: default
spec:
  capability: "unix"
  script: |
    #!/bin/bash
    echo "Starting test remote task..."
    echo "Hello from the remote environment! Current user: $TEST_USER"
    echo "Executing critical operations..."
    sleep 2
    echo "Task complete!"
  cleanup: |
    #!/bin/bash
    echo "Running cleanup steps..."
  env:
    - name: TEST_USER
      value: "ginger-tester"

---
# Example 2 — via Tekton Pipeline using taskRef kind: RemoteTask
# Tekton creates a CustomRun; the controller translates it into a TaskRun.
#
# This gives you native pipeline view + logs in the Tekton dashboard.
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: example-remote-task-run-
  namespace: default
spec:
  pipelineSpec:
    tasks:
      - name: run-on-device
        taskRef:
          apiVersion: gingersociety.org/v1alpha1
          kind: RemoteTask
        params:
          - name: capability
            value: "unix"
          - name: script
            value: |
              #!/bin/bash
              echo "Starting test remote task..."
              echo "Hello from the remote environment! Current user: $TEST_USER"
              echo "Executing critical operations..."
              sleep 2
              echo "Task complete!"
          - name: cleanup
            value: |
              #!/bin/bash
              echo "Running cleanup steps..."
          - name: env
            value: |
              - name: TEST_USER
                value: "ginger-tester"

---
# Example 3 — via the reusable Tekton Task (installed by install-tekton-crd)
# Bypasses the CRD/controller entirely. Simplest option for pipeline authors.
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: example-remote-task-run-
  namespace: default
spec:
  pipelineSpec:
    tasks:
      - name: run-on-device
        taskRef:
          name: remote-task
          kind: Task
        params:
          - name: capability
            value: "unix"
          - name: script
            value: |
              #!/bin/bash
              export TEST_USER="ginger-tester"
              echo "Starting test remote task..."
              echo "Hello from the remote environment! Current user: $TEST_USER"
              sleep 2
              echo "Task complete!"
          - name: cleanup
            value: |
              #!/bin/bash
              echo "Running cleanup steps..."



sudo chmod +a "rpc-runner allow read,write" ~/.docker/run/docker.sock