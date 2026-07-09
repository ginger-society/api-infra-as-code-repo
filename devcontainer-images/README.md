docker build -t gingersociety/dev-container-node:latest -f Dockerfile.node.debian . --platform=linux/amd64 --no-cache

docker push gingersociety/dev-container-node:latest


docker build -t gingersociety/dev-container-rust:latest -f Dockerfile.rust.bullseye . --platform=linux/amd64 --no-cache

docker push gingersociety/dev-container-rust:latest


docker build -t gingersociety/dev-iac:latest -f Dockerfile.iac.debian . --platform=linux/amd64 --no-cache

docker push gingersociety/dev-iac:latest


 tree devcontainer-images 
devcontainer-images
├── Dockerfile.alpine
├── Dockerfile.debian
├── Dockerfile.iac.debian
├── Dockerfile.node.debian
├── Dockerfile.rust.bullseye
├── README.md
└── signing-keys
    ├── ca_key
    └── ca_key.pub

2 directories, 8 files
