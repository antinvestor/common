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

package notification

import (
	"context"
	"errors"

	"buf.build/gen/go/antinvestor/notification/connectrpc/go/notification/v1/notificationv1connect"
	notificationv1 "buf.build/gen/go/antinvestor/notification/protocolbuffers/go/notification/v1"
	"connectrpc.com/connect"

	common "github.com/antinvestor/common/v2"
	"github.com/antinvestor/common/v2/connection"
	"github.com/antinvestor/common/v2/servicecatalog"
)

// ErrDisabled is returned by NewClient when the target has no endpoint: the
// deployment runs without a notification service and callers should skip
// template sync and sends rather than fail.
var ErrDisabled = errors.New("notification: endpoint not configured")

// Target locates the notification service. Endpoint empty means disabled.
type Target struct {
	Endpoint              string
	WorkloadAPITargetPath string
}

// Enabled reports whether an endpoint is configured.
func (t Target) Enabled() bool { return t.Endpoint != "" }

// ServiceTarget converts to the common client target for service-notification.
func (t Target) ServiceTarget() common.ServiceTarget {
	return common.ServiceTarget{
		Endpoint:              t.Endpoint,
		ServiceID:             servicecatalog.ServiceNotification,
		WorkloadAPITargetPath: t.WorkloadAPITargetPath,
	}
}

// NewClient builds the authenticated Connect client for the notification
// service through connection.NewServiceClient (service-account credentials,
// workload API transport, client-level timeouts and retries all come from
// cfg). It returns ErrDisabled when target has no endpoint.
func NewClient(ctx context.Context, cfg any, target Target, extraOpts ...common.ClientOption) (notificationv1connect.NotificationServiceClient, error) {
	if !target.Enabled() {
		return nil, ErrDisabled
	}
	return connection.NewServiceClient(ctx, cfg, target.ServiceTarget(), notificationv1connect.NewNotificationServiceClient, extraOpts...)
}

// Sender delivers one notification. Production wraps the Connect client via
// NewSender; tests substitute a recorder.
type Sender interface {
	Send(ctx context.Context, n *notificationv1.Notification) error
}

// ConnectSender sends through the notification service Connect client.
type ConnectSender struct {
	cli notificationv1connect.NotificationServiceClient
}

// NewSender wraps the Connect client as a Sender.
func NewSender(cli notificationv1connect.NotificationServiceClient) *ConnectSender {
	return &ConnectSender{cli: cli}
}

// Send submits one notification and drains the status stream; the first
// stream error is returned.
func (s *ConnectSender) Send(ctx context.Context, n *notificationv1.Notification) error {
	stream, err := s.cli.Send(ctx, connect.NewRequest(notificationv1.SendRequest_builder{Data: []*notificationv1.Notification{n}}.Build()))
	if err != nil {
		return err
	}
	for stream.Receive() {
	}
	if err := stream.Err(); err != nil {
		_ = stream.Close()
		return err
	}
	return stream.Close()
}
