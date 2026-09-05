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

package notification_test

import (
	"context"
	"errors"
	"testing"

	notificationv1 "buf.build/gen/go/antinvestor/notification/protocolbuffers/go/notification/v1"
	"connectrpc.com/connect"
	"github.com/stretchr/testify/require"

	"github.com/antinvestor/common/notification"
)

type fakeSaver struct {
	reqs []*notificationv1.TemplateSaveRequest
	err  error
}

func (f *fakeSaver) TemplateSave(_ context.Context, req *connect.Request[notificationv1.TemplateSaveRequest]) (*connect.Response[notificationv1.TemplateSaveResponse], error) {
	if f.err != nil {
		return nil, f.err
	}
	f.reqs = append(f.reqs, req.Msg)
	return connect.NewResponse(notificationv1.TemplateSaveResponse_builder{}.Build()), nil
}

func shipped() notification.Template {
	return notification.Template{
		Name:      "template.demo.order.shipped",
		Subject:   "Order {{.reference}} shipped",
		Bodies:    map[string]string{notification.ChannelSMS: "Order {{.reference}} shipped.", notification.ChannelEmail: "<p>Order {{.reference}} shipped.</p>"},
		Variables: []string{"reference"},
	}
}

func TestSyncSendsSubjectChannelsAndExtra(t *testing.T) {
	saver := &fakeSaver{}
	n, err := notification.Sync(context.Background(), saver, "service_demo", []notification.Template{shipped()})
	require.NoError(t, err)
	require.Equal(t, 1, n)
	req := saver.reqs[0]
	require.Equal(t, "template.demo.order.shipped", req.GetName())
	require.Equal(t, notification.DefaultLanguage, req.GetLanguageCode())
	data := req.GetData().AsMap()
	require.Equal(t, "Order {{.reference}} shipped", data[notification.SubjectKey])
	require.Contains(t, data, notification.ChannelSMS)
	require.Contains(t, data, notification.ChannelEmail)
	extra := req.GetExtra().AsMap()
	require.Equal(t, "service_demo", extra[notification.ExtraOwner])
	require.Equal(t, []any{"reference"}, extra[notification.ExtraVariables])
}

func TestValidateRejectsBadNamesBodiesAndChannels(t *testing.T) {
	cases := map[string]func(*notification.Template){
		"camel case name":     func(t *notification.Template) { t.Name = "OrderShipped" },
		"too few segments":    func(t *notification.Template) { t.Name = "template.demo.shipped" },
		"subject as channel":  func(t *notification.Template) { t.Bodies = map[string]string{notification.SubjectKey: "x"} },
		"unparseable body":    func(t *notification.Template) { t.Bodies[notification.ChannelSMS] = "{{.unclosed" },
		"unparseable subject": func(t *notification.Template) { t.Subject = "{{.unclosed" },
		"long channel":        func(t *notification.Template) { t.Bodies["a-very-long-channel"] = "x" },
		"blank body":          func(t *notification.Template) { t.Bodies[notification.ChannelSMS] = "  " },
		"no bodies":           func(t *notification.Template) { t.Bodies = nil },
	}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			bad := shipped()
			mutate(&bad)
			require.Error(t, bad.Validate())
		})
	}
	require.NoError(t, shipped().Validate())
}

func TestRenderUsesDocumentedVariables(t *testing.T) {
	tpl := shipped()
	vars := map[string]any{"reference": "ORD-1"}
	sms, err := tpl.Render(notification.ChannelSMS, vars)
	require.NoError(t, err)
	require.Equal(t, "Order ORD-1 shipped.", sms)
	subject, err := tpl.RenderSubject(vars)
	require.NoError(t, err)
	require.Equal(t, "Order ORD-1 shipped", subject)
	_, err = tpl.Render("push", vars)
	require.Error(t, err)
	missing, err := tpl.Render(notification.ChannelSMS, nil)
	require.NoError(t, err)
	require.Contains(t, missing, "<no value>")
}

func TestSyncStopsAtFirstFailureAndRejectsDuplicates(t *testing.T) {
	saver := &fakeSaver{err: errors.New("boom")}
	n, err := notification.Sync(context.Background(), saver, "svc", []notification.Template{shipped()})
	require.Error(t, err)
	require.Equal(t, 0, n)

	n, err = notification.Sync(context.Background(), &fakeSaver{}, "svc", []notification.Template{shipped(), shipped()})
	require.Error(t, err)
	require.Equal(t, 1, n)
}

func TestNameNormalisesSegments(t *testing.T) {
	require.Equal(t, "template.imports.quote.quote_sent", notification.Name("imports", "quote", "QUOTE_SENT"))
	require.Equal(t, "template.imports.staff.quote_accepted", notification.Name("imports", "staff", "quote.accepted"))
	require.Equal(t, "template.orders.order.shipped_late", notification.Name("Orders", "order", " shipped late "))
	require.NoError(t, notification.ValidateName(notification.Name("imports", "order", "funded")))
	require.Error(t, notification.ValidateName(notification.Name("imports", "order")))
}

func TestRegistryAddsLooksUpAndSyncs(t *testing.T) {
	reg := notification.NewRegistry("service_demo")
	require.NoError(t, reg.Add(shipped()))
	require.Error(t, reg.Add(shipped()), "duplicate name")
	require.Error(t, reg.Add(notification.Template{Name: "bad"}))
	require.Panics(t, func() { reg.MustAdd(shipped()) })

	delivered := shipped()
	delivered.Name = "template.demo.order.delivered"
	reg.MustAdd(delivered)

	require.Equal(t, 2, reg.Len())
	require.Equal(t, []string{"template.demo.order.delivered", "template.demo.order.shipped"}, reg.Names())
	require.True(t, reg.Has(delivered.Name))
	got, ok := reg.Lookup(shipped().Name)
	require.True(t, ok)
	require.Equal(t, shipped().Subject, got.Subject)
	_, ok = reg.Lookup("template.demo.order.lost")
	require.False(t, ok)

	saver := &fakeSaver{}
	n, err := reg.Sync(context.Background(), saver)
	require.NoError(t, err)
	require.Equal(t, 2, n)
	require.Equal(t, "service_demo", saver.reqs[0].GetExtra().AsMap()[notification.ExtraOwner])
}
