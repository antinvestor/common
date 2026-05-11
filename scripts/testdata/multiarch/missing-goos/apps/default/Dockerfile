FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o /app/binary ./cmd/main.go

FROM cgr.dev/chainguard/static:latest
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
