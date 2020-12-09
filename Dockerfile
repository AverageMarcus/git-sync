FROM alpine/git

RUN apk update && apk add bash curl jq

WORKDIR /app

ADD sync.sh sync.sh

ENTRYPOINT ["/app/sync.sh"]
