# build-platforms: linux/amd64
FROM ubuntu:22.04 AS builder

WORKDIR /app
RUN apt-get update && apt-get install -y libtesseract-dev
COPY . .
RUN go build -o /app/binary ./cmd/main.go

FROM ubuntu:22.04
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
