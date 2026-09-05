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
	"fmt"

	"github.com/pitabwire/frame/v2"
	"github.com/pitabwire/frame/v2/setup"
	"github.com/pitabwire/util"
)

// SetupStepName is the setup plan step RegisterTemplateSync registers. It is
// deliberately not setup.NameBootstrap: frame keeps one step per name, so a
// service that registers several bootstrap steps under the conventional name
// silently keeps only the last one.
const SetupStepName = "notification-templates"

// SyncOption tunes RegisterTemplateSync.
type SyncOption func(*syncOptions)

type syncOptions struct {
	stepName  string
	required  bool
	newClient func(ctx context.Context) (Saver, error)
}

// Required makes a failed sync fail the setup job. The default is warn-only:
// a notification outage must not block a migrate job and therefore a
// rollout, so failures are logged at ERROR (where the application-errors
// alert sees them) and the plan continues.
func Required() SyncOption {
	return func(o *syncOptions) { o.required = true }
}

// WithStepName overrides SetupStepName.
func WithStepName(name string) SyncOption {
	return func(o *syncOptions) { o.stepName = name }
}

// WithSaver substitutes the client factory; for tests.
func WithSaver(newClient func(ctx context.Context) (Saver, error)) SyncOption {
	return func(o *syncOptions) { o.newClient = newClient }
}

// RegisterTemplateSync registers the setup step that upserts every template
// in reg with the notification service. The step is idempotent (TemplateSave
// is keyed by name) and runs on every deploy; with no endpoint configured it
// logs and skips so a deployment without the notification service still
// migrates.
func RegisterTemplateSync(svc *frame.Service, cfg any, target Target, reg *Registry, opts ...SyncOption) {
	o := syncOptions{stepName: SetupStepName}
	for _, opt := range opts {
		opt(&o)
	}
	if o.newClient == nil {
		o.newClient = func(ctx context.Context) (Saver, error) {
			return NewClient(ctx, cfg, target)
		}
	}
	svc.Setup().Register(setup.Func{
		StepName: o.stepName,
		Fn: func(ctx context.Context) error {
			return syncStep(ctx, target, reg, o)
		},
	})
}

func syncStep(ctx context.Context, target Target, reg *Registry, o syncOptions) error {
	log := util.Log(ctx).WithField("owner", reg.Owner()).WithField("templates", reg.Len())
	if !target.Enabled() {
		log.Info("notification template sync skipped: no endpoint configured")
		return nil
	}
	fail := func(err error, registered int) error {
		err = fmt.Errorf("notification template sync: %w", err)
		if o.required {
			return err
		}
		log.WithError(err).WithField("registered", registered).Error("notification template sync failed; continuing")
		return nil
	}
	cli, err := o.newClient(ctx)
	if err != nil {
		return fail(err, 0)
	}
	registered, err := reg.Sync(ctx, cli)
	if err != nil {
		return fail(err, registered)
	}
	log.WithField("registered", registered).Info("notification templates registered")
	return nil
}
