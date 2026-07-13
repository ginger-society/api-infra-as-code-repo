# Run this on M series macbooks

docker build --progress=plain -t docker.gingersociety.org/ginger-society/multi-arch-rust:latest-arm64 --platform=linux/arm64 . -f multi-arch-rust.Dockerfile
docker push docker.gingersociety.org/ginger-society/multi-arch-rust:latest-arm64

docker build --progress=plain -t docker.gingersociety.org/ginger-society/multi-arch-rust:latest-amd64 --platform=linux/amd64 . -f multi-arch-rust.Dockerfile
docker push docker.gingersociety.org/ginger-society/multi-arch-rust:latest-amd64




docker manifest create --amend docker.gingersociety.org/ginger-society/multi-arch-rust:latest \
    docker.gingersociety.org/ginger-society/multi-arch-rust:latest-amd64 \
    docker.gingersociety.org/ginger-society/multi-arch-rust:latest-arm64

docker manifest push docker.gingersociety.org/ginger-society/multi-arch-rust:latest