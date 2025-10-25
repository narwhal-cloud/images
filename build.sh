docker buildx create --name multiplatform-builder --use
docker buildx inspect multiplatform-builder --bootstrap
docker buildx build --platform linux/amd64,linux/arm64 --tag narwhalcloud/debian:podman --push --file Debian.Dockerfile .
docker buildx build --platform linux/amd64,linux/arm64 --tag narwhalcloud/alpine:podman --push --file Alpine.Dockerfile .
#docker buildx rm multiplatform-builder