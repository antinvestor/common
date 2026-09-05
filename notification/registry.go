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
	"sort"
	"sync"
)

// Registry is the set of templates one service owns. Add templates from
// package init (or a sync.Once builder), then hand the registry to
// RegisterTemplateSync; tests iterate All to render every template.
//
// Registry is safe for concurrent reads once populated; adds are guarded so
// init order between packages does not matter.
type Registry struct {
	owner  string
	mu     sync.RWMutex
	byName map[string]Template
}

// NewRegistry returns an empty registry for owner (the calling service's
// name, e.g. "service_orders"; recorded on every registered template).
func NewRegistry(owner string) *Registry {
	return &Registry{owner: owner, byName: make(map[string]Template)}
}

// Owner returns the service name recorded on every template.
func (r *Registry) Owner() string { return r.owner }

// Add validates and adds templates; a duplicate name is an error.
func (r *Registry) Add(templates ...Template) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, t := range templates {
		if err := t.Validate(); err != nil {
			return err
		}
		if _, dup := r.byName[t.Name]; dup {
			return fmt.Errorf("template %s declared twice", t.Name)
		}
		r.byName[t.Name] = t
	}
	return nil
}

// MustAdd is Add for package-level declarations; it panics on error so a
// malformed template fails at process start, not at the first send.
func (r *Registry) MustAdd(templates ...Template) {
	if err := r.Add(templates...); err != nil {
		panic(err)
	}
}

// Lookup returns the template with the given name.
func (r *Registry) Lookup(name string) (Template, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	t, ok := r.byName[name]
	return t, ok
}

// Has reports whether name is registered.
func (r *Registry) Has(name string) bool {
	_, ok := r.Lookup(name)
	return ok
}

// All returns every template sorted by name.
func (r *Registry) All() []Template {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]Template, 0, len(r.byName))
	for _, t := range r.byName {
		out = append(out, t)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

// Names returns every registered name, sorted.
func (r *Registry) Names() []string {
	all := r.All()
	names := make([]string, len(all))
	for i, t := range all {
		names[i] = t.Name
	}
	return names
}

// Len returns the number of registered templates.
func (r *Registry) Len() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.byName)
}

// Sync registers every template with the notification service.
func (r *Registry) Sync(ctx context.Context, cli Saver) (int, error) {
	return Sync(ctx, cli, r.owner, r.All())
}
