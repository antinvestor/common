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
	"errors"
	"io"
	"sync"
	"time"

	"connectrpc.com/connect/v2"
	"github.com/pitabwire/util"
)

// LoggingInterceptorOption configures the logging interceptors.
type LoggingInterceptorOption func(*loggingInterceptor)

// loggingInterceptor logs requests and responses.
type loggingInterceptor struct {
	// Options for controlling logging behavior
	logRequests  bool
	logResponses bool
	logHeaders   bool
}

func newLoggingInterceptor(opts []LoggingInterceptorOption) *loggingInterceptor {
	l := &loggingInterceptor{
		logRequests:  true,
		logResponses: true,
		logHeaders:   false, // Don't log headers by default for security
	}

	for _, opt := range opts {
		opt(l)
	}

	return l
}

// NewLoggingClientInterceptor returns a client interceptor that logs each
// outbound RPC when it starts and when it ends. A unary call ends when its
// response arrives; a stream ends when Receive reports io.EOF or an error, or
// when the caller closes it.
func NewLoggingClientInterceptor(_ context.Context, opts ...LoggingInterceptorOption) connect.ClientInterceptor {
	return newLoggingInterceptor(opts).client
}

// NewLoggingServerInterceptor returns a server interceptor that logs each
// inbound RPC, unary or streaming, when it starts and when the handler returns.
func NewLoggingServerInterceptor(_ context.Context, opts ...LoggingInterceptorOption) connect.ServerInterceptor {
	return newLoggingInterceptor(opts).server
}

// WithLogRequests enables or disables request logging.
func WithLogRequests(enabled bool) LoggingInterceptorOption {
	return func(l *loggingInterceptor) {
		l.logRequests = enabled
	}
}

// WithLogResponses enables or disables response logging.
func WithLogResponses(enabled bool) LoggingInterceptorOption {
	return func(l *loggingInterceptor) {
		l.logResponses = enabled
	}
}

// WithLogHeaders enables or disables header logging.
// Note: Be careful when enabling this as headers may contain sensitive information.
func WithLogHeaders(enabled bool) LoggingInterceptorOption {
	return func(l *loggingInterceptor) {
		l.logHeaders = enabled
	}
}

func (l *loggingInterceptor) logRequest(ctx context.Context, spec connect.Spec, isClient bool, header *connect.Header) {
	if !l.logRequests {
		return
	}

	logger := util.Log(ctx).WithFields(map[string]any{
		"procedure":   spec.Procedure,
		"stream_type": spec.StreamType.String(),
		"is_client":   isClient,
	})

	if l.logHeaders && header != nil {
		headers := make(map[string]string, header.Len())
		for name, values := range header.All() {
			if len(values) > 0 {
				headers[name] = values[0]
			}
		}
		logger = logger.WithField("headers", headers)
	}

	if isClient {
		logger.Debug("request sent")
	} else {
		logger.Debug("request received")
	}
}

func (l *loggingInterceptor) logResponse(
	ctx context.Context,
	spec connect.Spec,
	isClient bool,
	err error,
	duration time.Duration,
) {
	if !l.logResponses {
		return
	}

	logger := util.Log(ctx).WithFields(map[string]any{
		"procedure":   spec.Procedure,
		"stream_type": spec.StreamType.String(),
		"duration_ms": duration.Milliseconds(),
		"is_client":   isClient,
	})

	if err != nil {
		code := connect.CodeOf(err)
		logger = logger.WithField("error_code", code.String())
		switch code {
		case connect.CodeInternal, connect.CodeUnavailable,
			connect.CodeDataLoss, connect.CodeUnknown:
			logger.WithError(err).Error("request failed")
		default:
			logger.WithError(err).Warn("request failed")
		}
		return
	}

	logger.Debug("request completed")
}

func (l *loggingInterceptor) client(next connect.ClientFunc) connect.ClientFunc {
	return func(ctx context.Context, spec connect.Spec) (connect.ClientStream, error) {
		start := time.Now()

		var header *connect.Header
		if info, ok := connect.CallInfoForClientContext(ctx); ok {
			header = info.RequestHeader()
		}
		l.logRequest(ctx, spec, true, header)

		stream, err := next(ctx, spec)
		if err != nil {
			l.logResponse(ctx, spec, true, err, time.Since(start))
			return nil, err
		}

		return &loggingClientStream{
			ClientStream: stream,
			finish: func(err error) {
				l.logResponse(ctx, spec, true, err, time.Since(start))
			},
		}, nil
	}
}

func (l *loggingInterceptor) server(next connect.ServerFunc) connect.ServerFunc {
	return func(ctx context.Context, spec connect.Spec, stream connect.ServerStream) error {
		start := time.Now()

		var header *connect.Header
		if info, ok := connect.CallInfoForServerContext(ctx); ok {
			header = info.RequestHeader()
		}
		l.logRequest(ctx, spec, false, header)

		err := next(ctx, spec, stream)

		l.logResponse(ctx, spec, false, err, time.Since(start))
		return err
	}
}

// loggingClientStream logs the end of a client RPC exactly once.
type loggingClientStream struct {
	connect.ClientStream

	once   sync.Once
	finish func(error)
}

func (s *loggingClientStream) done(err error) {
	s.once.Do(func() { s.finish(err) })
}

func (s *loggingClientStream) Receive(msg any) error {
	err := s.ClientStream.Receive(msg)
	switch {
	case err == nil:
	case errors.Is(err, io.EOF):
		s.done(nil)
	default:
		s.done(err)
	}
	return err
}

func (s *loggingClientStream) Close() error {
	err := s.ClientStream.Close()
	s.done(err)
	return err
}
