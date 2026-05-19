FROM alpine:latest AS builder

ARG TARGETARCH=amd64

WORKDIR /tmp

RUN apk add --no-cache curl

# ttyd (multi-arch)
RUN case "${TARGETARCH}" in \
        amd64) TTYD_ARCH="x86_64" ;; \
        arm64) TTYD_ARCH="aarch64" ;; \
        arm) TTYD_ARCH="armhf" ;; \
        386) TTYD_ARCH="i686" ;; \
        *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -SL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${TTYD_ARCH}" \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# cloudflared
RUN curl -SL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH} \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

FROM alpine:latest

RUN apk add --no-cache \
    nginx \
    supervisor \
    ca-certificates \
    tzdata \
    bash

ARG TARGETARCH

COPY --from=builder /usr/local/bin/ttyd /usr/local/bin/ttyd
COPY --from=builder /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy pre-built komari binary based on TARGETARCH
COPY komari-linux-${TARGETARCH} /usr/local/bin/komari
RUN chmod +x /usr/local/bin/komari

COPY conf/nginx.conf /etc/nginx/http.d/default.conf
COPY conf/supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80

VOLUME ["/app/data"]

ENTRYPOINT ["/entrypoint.sh"]
