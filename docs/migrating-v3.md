# Migrating from common v2 to v3

common v3 moves the Go side to [connect-go v2](https://github.com/connectrpc/connect-go/blob/v2.0.0/docs/v2-migration.md)
(`connectrpc.com/connect/v2`). Its public API exposes Connect client and
interceptor types, so the root module path changes to
`github.com/antinvestor/common/v3`.

Migrate a service to common v3 in the same change that moves it to
[frame v3](https://github.com/pitabwire/frame/blob/main/docs/migrating-v3.md).
Both use connect v2, and the generated clients and handlers must too.

The Dart packages (`sdk/dart/common`, `ui_core`) and the protos are unchanged
by this release.

## 1. Versions

| Module | Before | After |
| --- | --- | --- |
| `github.com/antinvestor/common/v2` | v2.0.8 | `github.com/antinvestor/common/v3` v3.0.0 |
| `github.com/antinvestor/common/audit` | pseudo-version (untagged) | v0.1.0 |
| `github.com/antinvestor/common/notification` | v0.1.0 | v0.2.0 |
| `github.com/antinvestor/common/auditverify`, `tools/*` | unchanged | unchanged (no Connect code) |
| `github.com/pitabwire/frame/v2` | v2.1.x | `github.com/pitabwire/frame/v3` v3.0.0 |
| `connectrpc.com/connect` | v1.20 / v1.21 | `connectrpc.com/connect/v2` v2.0.0 |
| BSR connect SDKs | `buf.build/gen/go/antinvestor/<m>/connectrpc/go` | `buf.build/gen/go/antinvestor/<m>/connectrpc/go/v2` |

The BSR generates connect v2 SDKs with the `buf.build/connectrpc/go:v2.0.0`
plugin into a separate `/v2` module. The import path gains `/v2` after
`connectrpc/go`:

```go
// v1
import "buf.build/gen/go/antinvestor/profile/connectrpc/go/profile/v1/profilev1connect"
// v2
import "buf.build/gen/go/antinvestor/profile/connectrpc/go/v2/profile/v1/profilev1connect"
```

```sh
go get buf.build/gen/go/antinvestor/profile/connectrpc/go/v2@latest
```

The `protocolbuffers/go` message modules do not change.

## 2. Order of work

1. Follow steps 1 to 5 of frame's migration guide: rewrite frame imports, run
   `connect-go-v2-migrate -w`, regenerate, and run the tool again.
2. Rewrite common imports:
   ```sh
   grep -rl 'github.com/antinvestor/common/v2' --include='*.go' . \
     | xargs sed -i 's#github.com/antinvestor/common/v2#github.com/antinvestor/common/v3#g'
   ```
3. Move each BSR connect SDK import to its `/v2` module (section 1).
4. Fix the common call sites listed in section 3.
5. Update and tidy:
   ```sh
   go get github.com/antinvestor/common/v3@v3.0.0 \
       github.com/antinvestor/common/audit@v0.1.0 \
       github.com/antinvestor/common/notification@v0.2.0 \
       github.com/pitabwire/frame/v3@v3.0.0 connectrpc.com/connect/v2@v2.0.0
   go mod tidy
   ```
6. Run `go build ./... && go vet ./... && go test ./...`.

## 3. API changes

### connection

| Symbol | v2 | v3 |
| --- | --- | --- |
| `ConnectServiceClientFactory[T]` | `func(connect.HTTPClient, string, ...connect.ClientOption) T` | `func(*connect.Client) T` |
| `ConnectClientBase.Options(...connect.ClientOption)` | returned client options | removed; use `ConnectClient`, `Interceptors` and `TransportOptions` |
| `ConnectClientBase.ConnectClient(...connecthttp.Option)` | n/a | new; returns the `*connect.Client` (HTTP transport plus interceptors) |
| `ConnectClientBase.Interceptors()` | n/a | new; `[]connect.ClientInterceptor` |
| `ConnectClientBase.TransportOptions(...connecthttp.Option)` | n/a | new; `WithHTTPGet`, then `WithConnectTransportOptions`, then the arguments |
| `common.WithConnectTransportOptions(...connecthttp.Option)` | n/a | new `ClientOption` |

v2 generated constructors take a `*connect.Client`, so they fit the new
factory type unchanged. Most services do not need to change these calls:

```go
// v2 and v3 read the same
cli, err := connection.NewServiceClient(ctx, cfg, target, profilev1connect.NewProfileServiceClient)
```

If you built clients yourself from `ConnectClientBase`:

```go
// v2
cli := profilev1connect.NewProfileServiceClient(base.Client(), base.Endpoint(), base.Options()...)
// v3
cli := profilev1connect.NewProfileServiceClient(base.ConnectClient())
```

### interceptors

Each interceptor is now a connect v2 function type. The v1
`connect.Interceptor` interface, with `WrapUnary`, `WrapStreamingClient` and
`WrapStreamingHandler`, no longer exists.

| Symbol | v2 | v3 |
| --- | --- | --- |
| `NewAuthInterceptor(...)` | `connect.Interceptor` | `connect.ClientInterceptor` |
| `NewPartitionInfoInterceptor(clientInfo)` | `connect.Interceptor` | `connect.ClientInterceptor` |
| `NewLoggingInterceptor(ctx, ...)` | `connect.Interceptor` (client and server) | removed; use `NewLoggingClientInterceptor` or `NewLoggingServerInterceptor` |
| `NewLoggingClientInterceptor(ctx, ...)` | n/a | `connect.ClientInterceptor` |
| `NewLoggingServerInterceptor(ctx, ...)` | n/a | `connect.ServerInterceptor` |
| `NewLoggingTransport`, `WrapClient` | unchanged | unchanged |

Client interceptors go to `connect.NewClient(transport, interceptors...)`.
Server interceptors go to `connect.NewServer(interceptors...)`.

### audit (`github.com/antinvestor/common/audit` v0.1.0)

| Symbol | v0 pseudo-version | v0.1.0 |
| --- | --- | --- |
| `NewInterceptor`, `NewInterceptorWithConfig` | `connect.Interceptor` | `connect.ServerInterceptor` |
| `Interceptor` (exported struct) | had `WrapUnary` and friends | removed; use the constructors |
| `NewConnectClient` | `(connect.HTTPClient, string, ...connect.ClientOption)` | `(*connect.Client)` |
| `NewAuditClient(baseURL, httpClient)` | unchanged signature | unchanged signature |
| `Config.AuditShouldSkipRPC(connect.Spec)` | connect v1 `Spec` | connect v2 `Spec` |
| `auditv1connect.AuditServiceClient` (in signatures) | `…/connectrpc/go/…` | `…/connectrpc/go/v2/…` |

Wire the audit interceptor into the server chain:

```go
// v2
auditInterceptor := audit.NewInterceptor("service_profile", auditCli)
interceptors, err := svc.ConnectDefaultInterceptors(ctx, authenticator, auditInterceptor)
path, h := profilev1connect.NewProfileServiceHandler(impl, connect.WithInterceptors(interceptors...))

// v3
auditInterceptor := audit.NewInterceptor("service_profile", auditCli)
interceptors, err := svc.ConnectDefaultInterceptors(ctx, authenticator, auditInterceptor)
server := connect.NewServer(interceptors...)
profilev1connect.RegisterProfileServiceHandler(server, impl)
connecthttp.Mount(mux, server)
```

The audit interceptor now runs once per RPC for every RPC type, unary and
streaming alike.

### notification (`github.com/antinvestor/common/notification` v0.2.0)

| Symbol | v0.1.0 | v0.2.0 |
| --- | --- | --- |
| `Saver.TemplateSave` | `(ctx, *connect.Request[TemplateSaveRequest]) (*connect.Response[TemplateSaveResponse], error)` | `(ctx, *TemplateSaveRequest) (*TemplateSaveResponse, error)` |
| `NewClient`, `NewSender` | v1 `NotificationServiceClient` | v2 `NotificationServiceClient` (`…/connectrpc/go/v2/…`) |
| `RegisterTemplateSync(svc *frame.Service, …)` | frame v2 | frame v3 |

## 4. Behavior changes

- **The auth interceptor fails fast.** If the token source cannot produce a
  token, the RPC fails with `CodeUnauthenticated` before it is sent. This now
  applies to streaming RPCs as well. In v2, a streaming call with no token was
  sent with an empty `Authorization` header. A client with neither a token
  source nor an API key sends no `Authorization` header; in v2 it panicked.
- **Headers on every RPC type.** The auth and partition interceptors set
  `Authorization`, `X-Ai-Api-Client` and the `X-Tenant-Id`, `X-Partition-Id`
  and `X-Access-Id` tenancy headers on unary and streaming RPCs alike.
- **Read limit.** connect v2 caps each received message at 4 MiB by default,
  for clients as well as handlers. In v1 there was no cap. If a client
  receives larger messages, raise the limit when you build it:
  ```go
  cli, err := connection.NewServiceClient(ctx, cfg, target, filesv1connect.NewFilesServiceClient,
      common.WithConnectTransportOptions(connecthttp.WithReadMaxBytes(32<<20)))
  ```
- **Logging fields.** The logging interceptors log `stream_type` in place of
  the HTTP `method`. The client interceptor logs the end of a call once: when
  the response or `io.EOF` arrives, when an error does, or when the caller
  closes the stream.
- **Errors.** Only a `*connect.Error` that a handler builds reaches the
  client with its message. See frame's guide, section 4, "Errors".

## 5. Testing

v2 clients do not depend on HTTP. To test against the real interceptor chain
without a listener, use `connectinprocess`:

```go
server := connect.NewServer(audit.NewInterceptor("service_profile", nil))
profilev1connect.RegisterProfileServiceHandler(server, impl)
cli := profilev1connect.NewProfileServiceClient(
    connect.NewClient(connectinprocess.New(server), interceptors.NewAuthInterceptor(interceptors.WithAPIKey("k"))),
)
```

Set request headers on a client call with `connect.NewClientContext`:

```go
ctx, info := connect.NewClientContext(ctx)
info.RequestHeader().Set("X-Profile", "person-1")
res, err := cli.GetById(ctx, req)
```
