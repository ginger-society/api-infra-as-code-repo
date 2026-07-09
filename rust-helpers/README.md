build and push images using

./docker-images.sh

then

sh <(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/refs/heads/main/rust-helpers/builder.sh)
sh <(curl -fsSL https://raw.githubusercontent.com/ginger-society/infra-as-code-repo/refs/heads/main/rust-helpers/upload.sh)