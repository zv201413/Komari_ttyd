FROM alpine:latest AS builder

ARG TARGETARCH=amd64

WORKDIR /tmp

RUN apk add --no-cache curl

# ttyd
RUN curl -SL https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# cloudflared
RUN curl -SL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH} \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# Komari v1.2.1-hotfix (fork: zv201413/komari_new)
RUN curl -SL https://github.com/zv201413/komari_new/releases/download/v1.2.1-hotfix/komari-linux-${TARGETARCH} \
    -o /usr/local/bin/komari && chmod +x /usr/local/bin/komari

FROM alpine:latest

RUN apk add --no-cache \
    nginx \
    supervisor \
    ca-certificates \
    tzdata \
    bash

COPY --from=builder /usr/local/bin/ttyd /usr/local/bin/ttyd
COPY --from=builder /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY --from=builder /usr/local/bin/komari /usr/local/bin/komari

COPY conf/nginx.conf /etc/nginx/http.d/default.conf
COPY conf/supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80

VOLUME ["/app/data"]

ENTRYPOINT ["/entrypoint.sh"]
