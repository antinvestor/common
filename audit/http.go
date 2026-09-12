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

package audit

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	auditv1connect "buf.build/gen/go/antinvestor/audit/connectrpc/go/audit/v1/auditv1connect"
)

// HTTPMiddleware returns an http.Handler middleware that audits REST calls
// with the same actor rule, enrichment and synchronous soft-fail delivery
// as the Connect interceptor. Bodies are never captured.
//
//	auditedHandler := audit.HTTPMiddleware("service_profile", auditClient)(myHandler)
func HTTPMiddleware(
	serviceName string,
	auditClient auditv1connect.AuditServiceClient,
	cfgs ...Config,
) func(http.Handler) http.Handler {
	var cfg Config = DefaultConfig{}
	if len(cfgs) > 0 && cfgs[0] != nil {
		cfg = cfgs[0]
	}
	snd := newSender(serviceName, auditClient)
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if cfg.AuditShouldSkipHTTP(r.Method) {
				next.ServeHTTP(w, r)
				return
			}
			start := time.Now()
			actorCtx := r.Context()
			ctx := initEntry(r.Context())
			if e := entryFromContext(ctx); e != nil {
				e.IPAddress = extractIPAddress(r.Header)
				e.UserAgent = r.UserAgent()
				if e.Action == "" {
					e.Action = r.Method
				}
			}
			r = r.WithContext(ctx)

			rw := &statusWriter{ResponseWriter: w, statusCode: http.StatusOK}
			next.ServeHTTP(rw, r)

			actor, ok := ResolveActor(ctx)
			if !ok {
				return
			}
			var callErr error
			if rw.statusCode >= http.StatusBadRequest {
				callErr = &httpStatusError{status: rw.statusCode}
			}
			snd.record(actorCtx, ctx, actor, r.URL.Path, start, callErr)
		})
	}
}

type httpStatusError struct{ status int }

func (e *httpStatusError) Error() string { return fmt.Sprintf("http %d", e.status) }

// Is lets callers match any HTTP failure with errors.Is(err, ErrHTTPFailure).
func (e *httpStatusError) Is(target error) bool { return errors.Is(target, ErrHTTPFailure) }

// ErrHTTPFailure marks an audited HTTP call that returned >= 400.
var ErrHTTPFailure = errors.New("audited http call failed")

// statusWriter wraps http.ResponseWriter to capture the status code.
type statusWriter struct {
	http.ResponseWriter
	statusCode int
	written    bool
}

func (sw *statusWriter) WriteHeader(code int) {
	if !sw.written {
		sw.statusCode = code
		sw.written = true
	}
	sw.ResponseWriter.WriteHeader(code)
}

func (sw *statusWriter) Write(b []byte) (int, error) {
	if !sw.written {
		sw.written = true
	}
	return sw.ResponseWriter.Write(b)
}
