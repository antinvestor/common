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

	"connectrpc.com/connect/v2"
	"github.com/pitabwire/util"
)

// NewPartitionInfoInterceptor returns a client interceptor that stamps every
// outbound RPC with the X-Ai-Api-Client header and, when ctx carries tenancy
// information, the X-Tenant-Id, X-Partition-Id and X-Access-Id headers.
func NewPartitionInfoInterceptor(clientInfo string) connect.ClientInterceptor {
	return func(next connect.ClientFunc) connect.ClientFunc {
		return func(ctx context.Context, spec connect.Spec) (connect.ClientStream, error) {
			if info, ok := connect.CallInfoForClientContext(ctx); ok {
				header := info.RequestHeader()
				header.Set("X-Ai-Api-Client", clientInfo)
				setTenancyInfo(ctx, header)
			}
			return next(ctx, spec)
		}
	}
}

func setTenancyInfo(ctx context.Context, header *connect.Header) {
	tenancyInfo := util.GetTenancy(ctx)
	if tenancyInfo == nil {
		return
	}

	header.Set("X-Tenant-Id", tenancyInfo.GetTenantID())
	header.Set("X-Partition-Id", tenancyInfo.GetPartitionID())
	header.Set("X-Access-Id", tenancyInfo.GetAccessID())
}
