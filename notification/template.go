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
	"bytes"
	"context"
	"fmt"
	"strings"
	"text/template"

	"buf.build/gen/go/antinvestor/notification/connectrpc/go/notification/v1/notificationv1connect"
	notificationv1 "buf.build/gen/go/antinvestor/notification/protocolbuffers/go/notification/v1"
	"connectrpc.com/connect"
	"google.golang.org/protobuf/types/known/structpb"
)

const (
	// ChannelSMS and ChannelEmail are the channel types the notification
	// service routes on; a template body is keyed by one of them.
	ChannelSMS   = "sms"
	ChannelEmail = "email"

	// SubjectKey is the reserved data key that carries the subject.
	SubjectKey = "subject"

	// DefaultLanguage is used when a Template does not set Language.
	DefaultLanguage = "en"

	// ExtraOwner and ExtraVariables are the keys Sync fills in the
	// template's extra data when the template does not set them.
	ExtraOwner     = "owner"
	ExtraVariables = "variables"

	maxChannelLen = 10
)

// Template is one message in every channel it is delivered on.
type Template struct {
	// Name identifies the template: template.<service>.<entity>.<event>.
	Name string
	// Language is the BCP 47 code; DefaultLanguage when empty.
	Language string
	// Subject is used by channels that carry one (email). Optional.
	Subject string
	// Bodies holds one Go text/template body per channel type.
	Bodies map[string]string
	// Variables documents the payload keys the bodies reference.
	Variables []string
	// Extra is stored alongside the template (owner, notes); ExtraOwner and
	// ExtraVariables are filled by Sync when absent.
	Extra map[string]any
}

// New builds a template from a short and a long version of the message: the
// short one is saved as the SMS body, the long one as the email body. This is
// the shape every consumer should declare messages in.
func New(name, subject, short, long string, variables ...string) Template {
	return Template{
		Name:      name,
		Language:  DefaultLanguage,
		Subject:   subject,
		Bodies:    map[string]string{ChannelSMS: short, ChannelEmail: long},
		Variables: variables,
	}
}

// Short returns the SMS body.
func (t Template) Short() string { return t.Bodies[ChannelSMS] }

// Long returns the email body.
func (t Template) Long() string { return t.Bodies[ChannelEmail] }

// Saver is the slice of the notification client Sync needs.
type Saver interface {
	TemplateSave(ctx context.Context, req *connect.Request[notificationv1.TemplateSaveRequest]) (*connect.Response[notificationv1.TemplateSaveResponse], error)
}

// LanguageOrDefault returns the template language, or DefaultLanguage.
func (t Template) LanguageOrDefault() string {
	if t.Language == "" {
		return DefaultLanguage
	}
	return t.Language
}

// Validate checks the template is well formed and every body parses.
func (t Template) Validate() error {
	if err := ValidateName(t.Name); err != nil {
		return err
	}
	if len(t.Bodies) == 0 {
		return fmt.Errorf("template %s has no bodies", t.Name)
	}
	for channel, body := range t.Bodies {
		if channel == "" || channel == SubjectKey || len(channel) > maxChannelLen {
			return fmt.Errorf("template %s: channel %q is not a valid channel type", t.Name, channel)
		}
		if strings.TrimSpace(body) == "" {
			return fmt.Errorf("template %s: %s body is empty", t.Name, channel)
		}
		if _, err := parse(t.Name+"/"+channel, body); err != nil {
			return fmt.Errorf("template %s: %s body: %w", t.Name, channel, err)
		}
	}
	if t.Subject != "" {
		if _, err := parse(t.Name+"/subject", t.Subject); err != nil {
			return fmt.Errorf("template %s: subject: %w", t.Name, err)
		}
	}
	return nil
}

// Render executes the body for channel with vars. Variables the body
// references but vars does not carry render as "<no value>", so tests that
// render every template with the documented variables catch drift.
func (t Template) Render(channel string, vars map[string]any) (string, error) {
	body, ok := t.Bodies[channel]
	if !ok {
		return "", fmt.Errorf("template %s has no %s body", t.Name, channel)
	}
	return execute(t.Name+"/"+channel, body, vars)
}

// RenderSubject executes the subject with vars.
func (t Template) RenderSubject(vars map[string]any) (string, error) {
	return execute(t.Name+"/subject", t.Subject, vars)
}

// SaveRequest builds the upsert request for the template. owner names the
// calling service and is recorded in the template's extra data.
func (t Template) SaveRequest(owner string) (*notificationv1.TemplateSaveRequest, error) {
	if err := t.Validate(); err != nil {
		return nil, err
	}
	data := make(map[string]any, len(t.Bodies)+1)
	for channel, body := range t.Bodies {
		data[channel] = body
	}
	if t.Subject != "" {
		data[SubjectKey] = t.Subject
	}
	dataStruct, err := structpb.NewStruct(data)
	if err != nil {
		return nil, fmt.Errorf("template %s: data: %w", t.Name, err)
	}
	extra := make(map[string]any, len(t.Extra)+2)
	for k, v := range t.Extra {
		extra[k] = v
	}
	if _, ok := extra[ExtraOwner]; !ok && owner != "" {
		extra[ExtraOwner] = owner
	}
	if _, ok := extra[ExtraVariables]; !ok {
		vars := make([]any, 0, len(t.Variables))
		for _, v := range t.Variables {
			vars = append(vars, v)
		}
		extra[ExtraVariables] = vars
	}
	extraStruct, err := structpb.NewStruct(extra)
	if err != nil {
		return nil, fmt.Errorf("template %s: extra: %w", t.Name, err)
	}
	return notificationv1.TemplateSaveRequest_builder{
		Name:         t.Name,
		LanguageCode: t.LanguageOrDefault(),
		Data:         dataStruct,
		Extra:        extraStruct,
	}.Build(), nil
}

// Sync registers every template with the notification service. It returns
// the number registered before the first failure. owner names the calling
// service (e.g. "service_orders") and is recorded in each template's extra.
func Sync(ctx context.Context, cli Saver, owner string, templates []Template) (int, error) {
	seen := make(map[string]struct{}, len(templates))
	for i, t := range templates {
		key := t.Name + "/" + t.LanguageOrDefault()
		if _, dup := seen[key]; dup {
			return i, fmt.Errorf("template %s (%s) declared twice", t.Name, t.LanguageOrDefault())
		}
		seen[key] = struct{}{}
		req, err := t.SaveRequest(owner)
		if err != nil {
			return i, err
		}
		if _, err := cli.TemplateSave(ctx, connect.NewRequest(req)); err != nil {
			return i, fmt.Errorf("register template %s: %w", t.Name, err)
		}
	}
	return len(templates), nil
}

func parse(name, body string) (*template.Template, error) {
	return template.New(name).Parse(body)
}

func execute(name, body string, vars map[string]any) (string, error) {
	tmpl, err := parse(name, body)
	if err != nil {
		return "", err
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, vars); err != nil {
		return "", err
	}
	return buf.String(), nil
}

// Compile-time check that the generated client satisfies Saver.
var _ Saver = notificationv1connect.NotificationServiceClient(nil)
