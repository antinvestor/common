FROM --platform=$BUILDPLATFORM golang:1.26 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -o /app/binary ./cmd/main.go

FROM cgr.dev/chainguard/static:latest
COPY --from=builder /app/binary /default
ENTRYPOINT ["/default"]
