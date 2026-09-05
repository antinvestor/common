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
	"fmt"
	"regexp"
	"strings"
)

// NamePrefix starts every template name.
const NamePrefix = "template."

var (
	namePattern    = regexp.MustCompile(`^template\.[a-z0-9_]+(\.[a-z0-9_]+){2,}$`)
	segmentCleaner = regexp.MustCompile(`[^a-z0-9_]+`)
)

// Name builds template.<service>.<parts...>, lowercasing each part and
// folding anything that is not [a-z0-9_] into "_", so machine state names
// ("QUOTE_SENT"), dotted event names ("quote.accepted") and free text all
// yield a valid segment:
//
//	Name("imports", "quote", "QUOTE_SENT")    // template.imports.quote.quote_sent
//	Name("imports", "staff", "quote.accepted") // template.imports.staff.quote_accepted
func Name(service string, parts ...string) string {
	segments := make([]string, 0, len(parts)+1)
	segments = append(segments, Segment(service))
	for _, p := range parts {
		segments = append(segments, Segment(p))
	}
	return NamePrefix + strings.Join(segments, ".")
}

// Segment normalises one name segment: lowercase, [a-z0-9_] only.
func Segment(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = segmentCleaner.ReplaceAllString(s, "_")
	return strings.Trim(s, "_")
}

// ValidateName reports whether name follows template.<service>.<entity>.<event>.
func ValidateName(name string) error {
	if !namePattern.MatchString(name) {
		return fmt.Errorf("template name %q must look like template.<service>.<entity>.<event>", name)
	}
	return nil
}
