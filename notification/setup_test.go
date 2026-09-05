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

	"github.com/pitabwire/frame/v2"
	"github.com/stretchr/testify/require"

	"github.com/antinvestor/common/notification"
)

func newService(t *testing.T) (context.Context, *frame.Service) {
	t.Helper()
	ctx, svc := frame.NewServiceWithContext(context.Background(), frame.WithName("notification-test"))
	t.Cleanup(func() { svc.Stop(ctx) })
	return ctx, svc
}

func TestRegisterTemplateSyncRegistersEveryTemplate(t *testing.T) {
	ctx, svc := newService(t)
	reg := notification.NewRegistry("service_demo")
	reg.MustAdd(shipped())
	saver := &fakeSaver{}

	notification.RegisterTemplateSync(svc, nil, notification.Target{Endpoint: "https://notification.example"}, reg,
		notification.WithSaver(func(context.Context) (notification.Saver, error) { return saver, nil }))

	require.Equal(t, []string{notification.SetupStepName}, svc.SetupTaskNames())
	require.NoError(t, svc.Setup().Run(ctx))
	require.Len(t, saver.reqs, 1)
}

func TestRegisterTemplateSyncSkipsWithoutEndpoint(t *testing.T) {
	ctx, svc := newService(t)
	reg := notification.NewRegistry("service_demo")
	reg.MustAdd(shipped())
	called := false
	notification.RegisterTemplateSync(svc, nil, notification.Target{}, reg,
		notification.WithSaver(func(context.Context) (notification.Saver, error) { called = true; return &fakeSaver{}, nil }))
	require.NoError(t, svc.Setup().Run(ctx))
	require.False(t, called)
}

func TestRegisterTemplateSyncFailureIsWarnOnlyUnlessRequired(t *testing.T) {
	reg := notification.NewRegistry("service_demo")
	reg.MustAdd(shipped())
	target := notification.Target{Endpoint: "https://notification.example"}
	failing := notification.WithSaver(func(context.Context) (notification.Saver, error) { return &fakeSaver{err: errors.New("down")}, nil })

	ctx, svc := newService(t)
	notification.RegisterTemplateSync(svc, nil, target, reg, failing)
	require.NoError(t, svc.Setup().Run(ctx), "default is warn-only")

	ctx, svc = newService(t)
	notification.RegisterTemplateSync(svc, nil, target, reg, failing, notification.Required(), notification.WithStepName("templates"))
	require.Equal(t, []string{"templates"}, svc.SetupTaskNames())
	err := svc.Setup().Run(ctx)
	require.ErrorContains(t, err, "down")
}

func TestNewClientReportsDisabledTarget(t *testing.T) {
	_, err := notification.NewClient(context.Background(), nil, notification.Target{})
	require.ErrorIs(t, err, notification.ErrDisabled)
}
