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

package interceptors

import (
	"context"
	"fmt"
	"sync"

	"connectrpc.com/connect/v2"
	"golang.org/x/oauth2"
	"golang.org/x/sync/singleflight"
)

const authTokenHeader = "Authorization"

type AuthInterceptorOption func(*authInterceptor)
type authInterceptor struct {
	tokenSource oauth2.TokenSource // An oauth2 client to fetch new server token
	token       *oauth2.Token      // The JWT token that will be used in every call to the server
	apiKey      string             // An api key that never changes for a legacy api
	mu          sync.Mutex
	sf          singleflight.Group
}

// NewAuthInterceptor returns a client interceptor that sets the
// Authorization header on every outbound RPC, unary and streaming alike.
// The bearer token comes from the configured token source (refreshed once
// per expiry, shared across concurrent calls) or, failing that, the API key.
// A token-source failure aborts the RPC with CodeUnauthenticated.
func NewAuthInterceptor(opts ...AuthInterceptorOption) connect.ClientInterceptor {
	a := &authInterceptor{}
	for _, opt := range opts {
		opt(a)
	}

	return a.intercept
}

// WithTokenSource sets the OAuth2 client credentials config.
func WithTokenSource(tokenSource oauth2.TokenSource) AuthInterceptorOption {
	return func(a *authInterceptor) {
		a.tokenSource = tokenSource
	}
}

// WithAPIKey sets the legacy API key.
func WithAPIKey(key string) AuthInterceptorOption {
	return func(a *authInterceptor) {
		a.apiKey = key
	}
}

func (ai *authInterceptor) getTokenStr(_ context.Context) (string, error) {
	if ai.tokenSource == nil {
		return ai.apiKey, nil
	}

	ai.mu.Lock()
	if ai.token != nil && ai.token.Valid() {
		tok := ai.token.AccessToken
		ai.mu.Unlock()
		return tok, nil
	}
	ai.mu.Unlock()

	v, err, _ := ai.sf.Do("refresh", func() (any, error) {
		tok, err := ai.tokenSource.Token()
		if err != nil {
			return "", err
		}

		ai.mu.Lock()
		ai.token = tok
		ai.mu.Unlock()
		return tok.AccessToken, nil
	})
	if err != nil {
		return "", err
	}

	if tokenStr, ok := v.(string); ok {
		return tokenStr, nil
	}
	return "", fmt.Errorf("unexpected token type: %T", v)
}

func (ai *authInterceptor) intercept(next connect.ClientFunc) connect.ClientFunc {
	return func(ctx context.Context, spec connect.Spec) (connect.ClientStream, error) {
		tokenStr, err := ai.getTokenStr(ctx)
		if err != nil {
			return nil, connect.NewError(connect.CodeUnauthenticated, err.Error()).WithCause(err)
		}

		if tokenStr != "" {
			if info, ok := connect.CallInfoForClientContext(ctx); ok {
				info.RequestHeader().Set(authTokenHeader, "Bearer "+tokenStr)
			}
		}

		return next(ctx, spec)
	}
}
