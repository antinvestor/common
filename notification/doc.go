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

// Package notification is the consumer-side contract for the notification
// service: declaring message templates in code, registering them from a
// setup job, and building the authenticated client used to send.
//
// A consumer service declares its templates once — typically in a pkg/
// package of plain strings — collects them in a Registry, and calls
// RegisterTemplateSync from main so the setup Job upserts them on every
// deploy. TemplateSave is keyed by (tenant, partition, name), so the sync is
// idempotent and a changed body simply overwrites the previous one.
//
// Conventions:
//   - Name: template.<service>.<entity>.<event>, lowercase, dot separated.
//     Build names with Name to get this right.
//   - Bodies: keyed by channel type as the notification service routes them
//     (ChannelSMS, ChannelEmail, ...); bodies are Go text/template with
//     {{.variable}} keys.
//   - Subject: applies to channels that carry one (email); it travels in the
//     reserved SubjectKey of the save request.
//   - Variables: documents the payload keys the bodies use, so tests can
//     render every template and sends can be validated.
//
// # Declaring templates
//
//	var Registry = notification.NewRegistry("service_orders")
//
//	const OrderShipped = "template.orders.order.shipped"
//
//	func init() {
//	    Registry.MustAdd(notification.New(OrderShipped, "Order {{.reference}} shipped",
//	        "Order {{.reference}} shipped.",          // short → SMS
//	        "<p>Order {{.reference}} shipped.</p>",   // long  → email
//	        "reference"))
//	}
//
// # Wiring the setup job
//
//	notification.RegisterTemplateSync(svc, &cfg, notification.Target{
//	    Endpoint:              cfg.NotificationURL,
//	    WorkloadAPITargetPath: cfg.NotificationWorkloadAPITargetPath,
//	}, messages.Registry)
//
// # Sending
//
//	cli, err := notification.NewClient(ctx, &cfg, target)
//	sender := notification.NewSender(cli)
//	err = sender.Send(ctx, msg)
package notification
