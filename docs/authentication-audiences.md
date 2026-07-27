# OAuth audience contract

Common v2 keeps three security identifiers separate:

| Identifier | Meaning | Source |
| --- | --- | --- |
| Resource audience | The API that accepts an access token | The service's canonical URL |
| Requested audiences | Resource APIs that an OAuth client asks the issuer to include | `ServiceTarget.ServiceID` plus the configured audience base URL |
| Client assertion audience | The recipient of a `private_key_jwt` client assertion | The exact OAuth token endpoint URL |

Authorization grants are not audiences. OAuth scopes and authorization tuples or policies remain separate from token recipients.

## Creating an authenticated service client

Import Common using its semantic v2 path:

```go
import (
    common "github.com/antinvestor/common/v2"
    "github.com/antinvestor/common/v2/servicecatalog"
)

opts, err := common.ClientOptions(ctx, cfg, common.ServiceTarget{
    ServiceID: servicecatalog.ServiceProfile,
    Endpoint:  "profile.identity.svc.cluster.local:8443",
    Scopes:    []string{"system_int"},
})
```

The configuration must expose `GetOauth2AudienceBaseURL() string`. For example, a production base of `https://stawi.org` makes the profile recipient `https://profile.stawi.org`. Other environments can use a different canonical HTTPS base without changing application code.

Callers cannot supply arbitrary recipients through `ServiceTarget`. Common derives them from the stable service ID and rejects unknown IDs. Low-level OAuth clients that do not use `ServiceTarget` can set explicit recipients with `WithRequestedAudiences`.

For `private_key_jwt`, set `PrivateKeyJWTConfig.ClientAssertionAudience` only when it must differ from the configured token endpoint. It must never contain a resource audience.

## Extending the service catalog

Adding a resource service requires one reviewed change to `servicecatalog/catalog.go`:

1. add a stable `ServiceID` constant;
2. register its canonical audience path in `definitions`;
3. add it to the complete catalog round-trip test;
4. add the same ID and path to the deployment authentication catalog.

Audience paths are public security identifiers. Renaming a Kubernetes Service, route alias, or authorization namespace does not rename an audience.
