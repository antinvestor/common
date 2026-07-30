package servicecatalog_test

import (
	"testing"

	"github.com/antinvestor/common/v2/servicecatalog"
	"github.com/stretchr/testify/require"
)

func TestCatalogAudienceUsesConfigurableBaseURL(t *testing.T) {
	t.Parallel()

	catalog, err := servicecatalog.New("https://API.EXAMPLE.ORG/platform/")
	require.NoError(t, err)

	audience, err := catalog.Audience(servicecatalog.ServiceProfile)
	require.NoError(t, err)
	require.Equal(t, "https://api.example.org/platform/profile", audience)
}

func TestCatalogRejectsInvalidBaseAndUnknownService(t *testing.T) {
	t.Parallel()

	for _, value := range []string{
		"",
		"http://api.example.org",
		"https://api.example.org:443",
		"https://api.example.org?",
		"service_profile",
	} {
		_, err := servicecatalog.New(value)
		require.Error(t, err, value)
	}

	catalog, err := servicecatalog.New("https://api.example.org")
	require.NoError(t, err)
	_, err = catalog.Audience("unknown")
	require.Error(t, err)
}

func TestCatalogResolvesOnlyCanonicalEnvironmentAudience(t *testing.T) {
	t.Parallel()

	catalog, err := servicecatalog.New("https://api.example.org/platform")
	require.NoError(t, err)

	serviceID, err := catalog.ServiceForAudience("https://api.example.org/platform/profile")
	require.NoError(t, err)
	require.Equal(t, servicecatalog.ServiceProfile, serviceID)

	_, err = catalog.ServiceForAudience("https://api.other.example/platform/profile")
	require.Error(t, err)
	_, err = catalog.ServiceForAudience("https://api.example.org/platform/service_profile")
	require.Error(t, err)
}

func TestCatalogContainsCanonicalPlatformServices(t *testing.T) {
	t.Parallel()

	expected := map[servicecatalog.ServiceID]string{
		servicecatalog.ServiceAudit:                      "/audit",
		servicecatalog.ServiceAuthentication:             "/authentication",
		servicecatalog.ServiceBilling:                    "/billing",
		servicecatalog.ServiceChatAgent:                  "/chat-agent",
		servicecatalog.ServiceChatDrone:                  "/chat-drone",
		servicecatalog.ServiceChatGateway:                "/chat-gateway",
		servicecatalog.ServiceCheckout:                   "/checkout",
		servicecatalog.ServiceDevices:                    "/devices",
		servicecatalog.ServiceFiles:                      "/files",
		servicecatalog.ServiceFormstore:                  "/formstore",
		servicecatalog.ServiceFort:                       "/fort",
		servicecatalog.ServiceFunding:                    "/funding",
		servicecatalog.ServiceGeolocation:                "/geolocation",
		servicecatalog.ServiceIdentity:                   "/identity",
		servicecatalog.ServiceJobs:                       "/jobs",
		servicecatalog.ServiceLedger:                     "/ledger",
		servicecatalog.ServiceLimits:                     "/limits",
		servicecatalog.ServiceLoans:                      "/loans",
		servicecatalog.ServiceMatching:                   "/matching",
		servicecatalog.ServiceNotification:               "/notification",
		servicecatalog.ServiceNotificationAfricasTalking: "/notification-africastalking",
		servicecatalog.ServiceNotificationEmailSMTP:      "/notification-emailsmtp",
		servicecatalog.ServiceOperations:                 "/operations",
		servicecatalog.ServiceOpportunitiesCrawler:       "/opportunities-crawler",
		servicecatalog.ServiceOpportunitiesMaterializer:  "/opportunities-materializer",
		servicecatalog.ServiceOpportunitiesWriter:        "/opportunities-writer",
		servicecatalog.ServicePayment:                    "/payment",
		servicecatalog.ServicePaymentAirtel:              "/payment-airtel",
		servicecatalog.ServicePaymentJenga:               "/payment-jenga",
		servicecatalog.ServicePaymentMPesa:               "/payment-mpesa",
		servicecatalog.ServicePaymentMTN:                 "/payment-mtn",
		servicecatalog.ServicePaymentPawaPay:             "/payment-pawapay",
		servicecatalog.ServicePaymentPolar:               "/payment-polar",
		servicecatalog.ServicePaymentStripe:              "/payment-stripe",
		servicecatalog.ServiceProfile:                    "/profile",
		servicecatalog.ServiceQueuestore:                 "/queuestore",
		servicecatalog.ServiceRedirect:                   "/redirect",
		servicecatalog.ServiceSavings:                    "/savings",
		servicecatalog.ServiceSeed:                       "/seed",
		servicecatalog.ServiceSettings:                   "/settings",
		servicecatalog.ServiceStawi:                      "/stawi",
		servicecatalog.ServiceTenancy:                    "/tenancy",
		servicecatalog.ServiceThesa:                      "/thesa",
		servicecatalog.ServiceTrustage:                   "/trustage",
	}

	catalog, err := servicecatalog.New("https://api.example.org")
	require.NoError(t, err)
	require.Len(t, expected, 44)

	for serviceID, audiencePath := range expected {
		audience, audienceErr := catalog.Audience(serviceID)
		require.NoError(t, audienceErr, serviceID)
		require.Equal(t, "https://api.example.org"+audiencePath, audience, serviceID)

		resolved, resolveErr := catalog.ServiceForAudience(audience)
		require.NoError(t, resolveErr, serviceID)
		require.Equal(t, serviceID, resolved)
	}
}
