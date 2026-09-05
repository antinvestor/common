# notification

Consumer-side contract for the notification service, as a nested module
(`github.com/antinvestor/common/notification`) so the root module stays free of
the notification protos and frame.

| Need | Use |
|------|-----|
| Declare a message once, in code | `Template{Name, Subject, Bodies, Variables}` |
| Collect a service's templates | `NewRegistry(owner)` + `MustAdd` in package init |
| Register them from the setup Job on every deploy | `RegisterTemplateSync(svc, &cfg, Target{...}, registry)` |
| Build the authenticated client | `NewClient(ctx, &cfg, Target{...})` |
| Send | `NewSender(client).Send(ctx, msg)` |
| Build a valid name | `Name("imports", "quote", "QUOTE_SENT")` → `template.imports.quote.quote_sent` |
| Render in tests | `tpl.Render(ChannelSMS, vars)` / `tpl.RenderSubject(vars)` |

Template names follow `template.<service>.<entity>.<event>`. Bodies are Go
`text/template` keyed by channel (`sms`, `email`); the subject travels in the
reserved `subject` data key. `TemplateSave` on the notification service is an
upsert keyed by `(tenant, partition, name)`, so the sync is idempotent.

The setup step is named `notification-templates`, not `bootstrap`: frame keeps
one step per name, and a service with several bootstrap steps under the
conventional name silently keeps only the last one registered.

The sync is warn-only by default (logged at ERROR, plan continues) so a
notification outage never blocks a rollout; pass `Required()` to fail the job.

Recommended layout in a consumer: put the template strings in a `pkg/` package
(`pkg/messages`) that only imports this module, expose name constants and a
`Registry()` accessor, and keep the code that chooses and sends a message in
the app's `service/notifications` package.
