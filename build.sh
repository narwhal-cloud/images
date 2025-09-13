docker buildx create --name multiplatform-builder --use
docker buildx inspect multiplatform-builder --bootstrap
docker buildx build --platform linux/amd64,linux/arm64 --tag narwhalcloud/debian:latest --push --file Debian.Dockerfile .
docker buildx build --platform linux/amd64,linux/arm64 --tag narwhalcloud/alpine:latest --push --file Alpine.Dockerfile .
docker buildx rm multiplatform-builder