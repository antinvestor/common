// Copyright 2023-2026 Ant Investor Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package connection

import (
	"context"
	"errors"
	"net/http"
	"slices"
	"time"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connecthttp"
	"github.com/antinvestor/common/v3"
	"github.com/antinvestor/common/v3/connection/options"
	"github.com/antinvestor/common/v3/interceptors"
	"github.com/pitabwire/util"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"golang.org/x/oauth2"
)

const (
	defaultHTTPTimeoutSeconds     = 30
	defaultHTTPIdleTimeoutSeconds = 90
)

type ConnectClientBase struct {
	// http client to the service.
	client *http.Client

	endpoint string

	interceptors []connect.ClientInterceptor

	// transportOpts are the caller's connecthttp options from DialSettings.
	transportOpts []connecthttp.Option

	// The x-ant-* metadata to be sent with each request.
	xMetadata string
}

// Client returns the HTTP client that carries RPCs to the service.
func (ccb *ConnectClientBase) Client() *http.Client {
	return ccb.client
}

// Endpoint returns the service base URL.
func (ccb *ConnectClientBase) Endpoint() string {
	return ccb.endpoint
}

// Interceptors returns the client interceptor chain: authentication,
// partition headers and, when tracing is on, logging.
func (ccb *ConnectClientBase) Interceptors() []connect.ClientInterceptor {
	return slices.Clone(ccb.interceptors)
}

// TransportOptions returns the connecthttp options for the service transport:
// Connect GET for side-effect-free RPCs, then the options set through
// common.WithConnectTransportOptions, then opts.
func (ccb *ConnectClientBase) TransportOptions(opts ...connecthttp.Option) []connecthttp.Option {
	out := make([]connecthttp.Option, 0, 1+len(ccb.transportOpts)+len(opts))
	out = append(out, connecthttp.WithHTTPGet())
	out = append(out, ccb.transportOpts...)
	return append(out, opts...)
}

// ConnectClient returns a connect-go v2 client for the service: an HTTP
// transport over Client() to Endpoint() with TransportOptions(opts...), wrapped
// in Interceptors(). Pass it to a generated New<Service>Client constructor.
func (ccb *ConnectClientBase) ConnectClient(opts ...connecthttp.Option) *connect.Client {
	transport := connecthttp.NewTransport(ccb.client, ccb.endpoint, ccb.TransportOptions(opts...)...)
	return connect.NewClient(transport, ccb.interceptors...)
}

func (ccb *ConnectClientBase) SetInfo(keyval ...string) {
	kv := append([]string{"gl-go", VersionGo()}, keyval...)
	kv = append(kv, "connect", connect.Version)
	ccb.xMetadata = XAntHeader(kv...)
}

func (ccb *ConnectClientBase) GetInfo() string {
	return ccb.xMetadata
}

func (ccb *ConnectClientBase) SetTenancyInfo(
	ctx context.Context,
	tenancyInfo util.TenancyInfo,
) context.Context {
	return util.SetTenancy(ctx, tenancyInfo)
}

func NewConnectClientBase(ctx context.Context, opts ...common.ClientOption) (*ConnectClientBase, error) {
	ds, err := processAndValidateOpts(opts)
	if err != nil {
		return nil, err
	}

	baseHTTPDialOpts := append([]options.HTTPOption(nil), ds.HTTPDialOpts...)
	serviceHTTPDialOpts := append([]options.HTTPOption(nil), baseHTTPDialOpts...)
	if ds.HTTPEnableH2C {
		serviceHTTPDialOpts = append(serviceHTTPDialOpts, options.WithHTTPEnableH2C())
	}

	httpClient := ds.HTTPClient
	if httpClient == nil {
		httpClient, err = NewHTTPClient(ctx, serviceHTTPDialOpts...)
		if err != nil {
			return nil, err
		}
	}

	clientBase := ConnectClientBase{
		client:        httpClient,
		endpoint:      ds.Endpoint,
		transportOpts: slices.Clone(ds.ConnectTransportOpts),
	}
	clientBase.SetInfo()

	if ds.NoAuth {
		return &clientBase, nil
	}

	authInterceptor, err := newAuthInterceptor(ctx, ds, httpClient, baseHTTPDialOpts)
	if err != nil {
		return nil, err
	}

	clientBase.interceptors = []connect.ClientInterceptor{
		authInterceptor,
		interceptors.NewPartitionInfoInterceptor(clientBase.GetInfo())}

	if ds.TraceRequests || ds.TraceResponses || ds.TraceHeaders {
		clientBase.interceptors = append(clientBase.interceptors,
			interceptors.NewLoggingClientInterceptor(ctx,
				interceptors.WithLogRequests(ds.TraceRequests),
				interceptors.WithLogResponses(ds.TraceResponses),
				interceptors.WithLogHeaders(ds.TraceHeaders)))
	}

	return &clientBase, nil
}

func newAuthInterceptor(
	ctx context.Context,
	ds *common.DialSettings,
	serviceHTTPClient *http.Client,
	baseHTTPDialOpts []options.HTTPOption,
) (connect.ClientInterceptor, error) {
	var authOpts []interceptors.AuthInterceptorOption

	if ds.APICredential != "" {
		authOpts = append(authOpts, interceptors.WithAPIKey(ds.APICredential))
	}

	tokenSource, err := resolveTokenSource(ctx, ds, serviceHTTPClient, baseHTTPDialOpts)
	if err != nil {
		return nil, err
	}
	if tokenSource != nil {
		authOpts = append(authOpts, interceptors.WithTokenSource(tokenSource))
	}

	return interceptors.NewAuthInterceptor(authOpts...), nil
}

func resolveTokenSource(
	ctx context.Context,
	ds *common.DialSettings,
	serviceHTTPClient *http.Client,
	baseHTTPDialOpts []options.HTTPOption,
) (oauth2.TokenSource, error) {
	if ds.TokenEndpoint == "" && ds.TokenSource == nil {
		return nil, nil //nolint:nilnil // Nil token source means OAuth authentication is not configured.
	}

	tokenHTTPClient := serviceHTTPClient
	if ds.HTTPClient == nil {
		var err error
		tokenHTTPClient, err = NewHTTPClient(ctx, baseHTTPDialOpts...)
		if err != nil {
			return nil, err
		}
	}

	tokenSource, err := NewOAuth2TokenSource(ctx, ds, tokenHTTPClient)
	if err != nil && !errors.Is(err, errTokenEndpointNotConfigured) {
		return nil, err
	}

	return tokenSource, nil
}

// NewHTTPClient creates a new HTTP client with the provided options.
func NewHTTPClient(ctx context.Context, opts ...options.HTTPOption) (*http.Client, error) {
	cfg := &options.HTTPConfig{
		Timeout:     time.Duration(defaultHTTPTimeoutSeconds) * time.Second,
		IdleTimeout: time.Duration(defaultHTTPIdleTimeoutSeconds) * time.Second,
		Transport:   http.DefaultTransport,
	}

	for _, opt := range opts {
		opt(cfg)
	}

	base, closeIdleFn, err := prepareBaseTransport(ctx, cfg)
	if err != nil {
		return nil, err
	}

	if _, ok := base.(*otelhttp.Transport); !ok {
		base = otelhttp.NewTransport(base)
	}

	if closeIdleFn != nil {
		base = closeIdleTransport{
			inner:       base,
			closeIdleFn: closeIdleFn,
		}
	}

	// Optional: request/response logging
	if cfg.TraceRequests {
		base = interceptors.NewLoggingTransport(base,
			interceptors.WithTransportLogRequests(true),
			interceptors.WithTransportLogResponses(true),
			interceptors.WithTransportLogHeaders(cfg.TraceRequestHeaders),
			interceptors.WithTransportLogBody(true),
		)
	}

	client := &http.Client{
		Transport:     base,
		Timeout:       cfg.Timeout,
		Jar:           cfg.Jar,
		CheckRedirect: cfg.CheckRedirect,
	}

	if cfg.CliCredCfg != nil {
		oauth2Ctx := context.WithValue(ctx, oauth2.HTTPClient, client)
		// Get the OAuth2 client and preserve our transport configuration
		client = cfg.CliCredCfg.Client(oauth2Ctx)
		if closeIdleFn != nil {
			client.Transport = closeIdleTransport{
				inner:       client.Transport,
				closeIdleFn: closeIdleFn,
			}
		}
	}

	if client != nil {
		return client, nil
	}

	return nil, errors.New("failed to initialize HTTP client")
}
