# Stage 1: Download and extract (this layer is discarded)
FROM alpine:latest AS downloader
RUN wget https://github.com/splitsh/lite/releases/download/v1.0.1/lite_linux_amd64.tar.gz && \
    tar -zxpf lite_linux_amd64.tar.gz -C /usr/local/bin/

# Stage 2: Final lightweight image
FROM alpine:latest

LABEL repository="https://github.com/linkorb/splitsh-action"
LABEL homepage="https://github.com/linkorb/splitsh-action"
LABEL maintainer="Ayesh Karunaratne <ayesh@aye.sh>"
LABEL org.opencontainers.image.description="split-sh runner container image"

RUN apk add --no-cache \
    git \
    openssh-client \
    libc6-compat \
    github-cli \
    curl && \
    mkdir -p ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts

COPY --from=downloader /usr/local/bin/splitsh-lite /usr/local/bin/

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
