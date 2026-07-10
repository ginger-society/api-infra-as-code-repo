# Run this on M series macbooks

docker build -t gingersociety/multi-arch-rust:latest-arm64 --platform=linux/arm64 . -f multi-arch-rust.Dockerfile
docker push gingersociety/multi-arch-rust:latest-arm64

docker build -t gingersociety/multi-arch-rust:latest-amd64 --platform=linux/amd64 . -f multi-arch-rust.Dockerfile
docker push gingersociety/multi-arch-rust:latest-amd64




docker manifest create --amend gingersociety/multi-arch-rust:latest \
    gingersociety/multi-arch-rust:latest-amd64 \
    gingersociety/multi-arch-rust:latest-arm64

docker manifest push gingersociety/multi-arch-rust:latest