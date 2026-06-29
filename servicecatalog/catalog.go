package servicecatalog

import (
	"errors"
	"fmt"
	"net/url"
	"path"
	"strings"
)

// ServiceID is the stable platform identity used to derive a resource audience.
type ServiceID string

const (
	ServiceAudit                      ServiceID = "audit"
	ServiceAuthentication             ServiceID = "authentication"
	ServiceBilling                    ServiceID = "billing"
	ServiceChatDrone                  ServiceID = "chat-drone"
	ServiceChatGateway                ServiceID = "chat-gateway"
	ServiceCheckout                   ServiceID = "checkout"
	ServiceDevices                    ServiceID = "devices"
	ServiceFiles                      ServiceID = "files"
	ServiceFormstore                  ServiceID = "formstore"
	ServiceFort                       ServiceID = "fort"
	ServiceFunding                    ServiceID = "funding"
	ServiceGeolocation                ServiceID = "geolocation"
	ServiceIdentity                   ServiceID = "identity"
	ServiceJobs                       ServiceID = "jobs"
	ServiceLedger                     ServiceID = "ledger"
	ServiceLimits                     ServiceID = "limits"
	ServiceLoans                      ServiceID = "loans"
	ServiceMatching                   ServiceID = "matching"
	ServiceNotification               ServiceID = "notification"
	ServiceNotificationAfricasTalking ServiceID = "notification-africastalking"
	ServiceNotificationEmailSMTP      ServiceID = "notification-emailsmtp"
	ServiceOperations                 ServiceID = "operations"
	ServiceOpportunitiesCrawler       ServiceID = "opportunities-crawler"
	ServiceOpportunitiesMaterializer  ServiceID = "opportunities-materializer"
	ServiceOpportunitiesWriter        ServiceID = "opportunities-writer"
	ServicePayment                    ServiceID = "payment"
	ServicePaymentAirtel              ServiceID = "payment-airtel"
	ServicePaymentJenga               ServiceID = "payment-jenga"
	ServicePaymentMPesa               ServiceID = "payment-mpesa"
	ServicePaymentMTN                 ServiceID = "payment-mtn"
	ServicePaymentPawaPay             ServiceID = "payment-pawapay"
	ServicePaymentPolar               ServiceID = "payment-polar"
	ServicePaymentStripe              ServiceID = "payment-stripe"
	ServiceProfile                    ServiceID = "profile"
	ServiceQueuestore                 ServiceID = "queuestore"
	ServiceRedirect                   ServiceID = "redirect"
	ServiceSavings                    ServiceID = "savings"
	ServiceSeed                       ServiceID = "seed"
	ServiceSettings                   ServiceID = "settings"
	ServiceStawi                      ServiceID = "stawi"
	ServiceTenancy                    ServiceID = "tenancy"
	ServiceThesa                      ServiceID = "thesa"
	ServiceTrustage                   ServiceID = "trustage"
)

// Definition describes the canonical audience path for a service identity.
type Definition struct {
	ID           ServiceID
	AudiencePath string
}

var definitions = map[ServiceID]Definition{
	ServiceAudit:                      {ID: ServiceAudit, AudiencePath: "/audit"},
	ServiceAuthentication:             {ID: ServiceAuthentication, AudiencePath: "/authentication"},
	ServiceBilling:                    {ID: ServiceBilling, AudiencePath: "/billing"},
	ServiceChatDrone:                  {ID: ServiceChatDrone, AudiencePath: "/chat-drone"},
	ServiceChatGateway:                {ID: ServiceChatGateway, AudiencePath: "/chat-gateway"},
	ServiceCheckout:                   {ID: ServiceCheckout, AudiencePath: "/checkout"},
	ServiceDevices:                    {ID: ServiceDevices, AudiencePath: "/devices"},
	ServiceFiles:                      {ID: ServiceFiles, AudiencePath: "/files"},
	ServiceFormstore:                  {ID: ServiceFormstore, AudiencePath: "/formstore"},
	ServiceFort:                       {ID: ServiceFort, AudiencePath: "/fort"},
	ServiceFunding:                    {ID: ServiceFunding, AudiencePath: "/funding"},
	ServiceGeolocation:                {ID: ServiceGeolocation, AudiencePath: "/geolocation"},
	ServiceIdentity:                   {ID: ServiceIdentity, AudiencePath: "/identity"},
	ServiceJobs:                       {ID: ServiceJobs, AudiencePath: "/jobs"},
	ServiceLedger:                     {ID: ServiceLedger, AudiencePath: "/ledger"},
	ServiceLimits:                     {ID: ServiceLimits, AudiencePath: "/limits"},
	ServiceLoans:                      {ID: ServiceLoans, AudiencePath: "/loans"},
	ServiceMatching:                   {ID: ServiceMatching, AudiencePath: "/matching"},
	ServiceNotification:               {ID: ServiceNotification, AudiencePath: "/notification"},
	ServiceNotificationAfricasTalking: {ID: ServiceNotificationAfricasTalking, AudiencePath: "/notification-africastalking"},
	ServiceNotificationEmailSMTP:      {ID: ServiceNotificationEmailSMTP, AudiencePath: "/notification-emailsmtp"},
	ServiceOperations:                 {ID: ServiceOperations, AudiencePath: "/operations"},
	ServiceOpportunitiesCrawler:       {ID: ServiceOpportunitiesCrawler, AudiencePath: "/opportunities-crawler"},
	ServiceOpportunitiesMaterializer:  {ID: ServiceOpportunitiesMaterializer, AudiencePath: "/opportunities-materializer"},
	ServiceOpportunitiesWriter:        {ID: ServiceOpportunitiesWriter, AudiencePath: "/opportunities-writer"},
	ServicePayment:                    {ID: ServicePayment, AudiencePath: "/payment"},
	ServicePaymentAirtel:              {ID: ServicePaymentAirtel, AudiencePath: "/payment-airtel"},
	ServicePaymentJenga:               {ID: ServicePaymentJenga, AudiencePath: "/payment-jenga"},
	ServicePaymentMPesa:               {ID: ServicePaymentMPesa, AudiencePath: "/payment-mpesa"},
	ServicePaymentMTN:                 {ID: ServicePaymentMTN, AudiencePath: "/payment-mtn"},
	ServicePaymentPawaPay:             {ID: ServicePaymentPawaPay, AudiencePath: "/payment-pawapay"},
	ServicePaymentPolar:               {ID: ServicePaymentPolar, AudiencePath: "/payment-polar"},
	ServicePaymentStripe:              {ID: ServicePaymentStripe, AudiencePath: "/payment-stripe"},
	ServiceProfile:                    {ID: ServiceProfile, AudiencePath: "/profile"},
	ServiceQueuestore:                 {ID: ServiceQueuestore, AudiencePath: "/queuestore"},
	ServiceRedirect:                   {ID: ServiceRedirect, AudiencePath: "/redirect"},
	ServiceSavings:                    {ID: ServiceSavings, AudiencePath: "/savings"},
	ServiceSeed:                       {ID: ServiceSeed, AudiencePath: "/seed"},
	ServiceSettings:                   {ID: ServiceSettings, AudiencePath: "/settings"},
	ServiceStawi:                      {ID: ServiceStawi, AudiencePath: "/stawi"},
	ServiceTenancy:                    {ID: ServiceTenancy, AudiencePath: "/tenancy"},
	ServiceThesa:                      {ID: ServiceThesa, AudiencePath: "/thesa"},
	ServiceTrustage:                   {ID: ServiceTrustage, AudiencePath: "/trustage"},
}

// Catalog resolves stable service identities against one environment's canonical audience base URL.
type Catalog struct {
	baseURL string
}

// New validates an HTTPS audience base URL and returns its service catalog.
func New(baseURL string) (*Catalog, error) {
	normalized, err := normalizeBaseURL(baseURL)
	if err != nil {
		return nil, err
	}
	return &Catalog{baseURL: normalized}, nil
}

// DefinitionFor returns the registered definition for a stable service identity.
func DefinitionFor(serviceID ServiceID) (Definition, error) {
	definition, ok := definitions[serviceID]
	if !ok {
		return Definition{}, fmt.Errorf("unknown service ID %q", serviceID)
	}
	return definition, nil
}

// Audience returns the canonical resource audience for a service in this catalog's environment.
func (c *Catalog) Audience(serviceID ServiceID) (string, error) {
	if c == nil {
		return "", errors.New("service catalog is required")
	}
	definition, err := DefinitionFor(serviceID)
	if err != nil {
		return "", err
	}
	return c.baseURL + definition.AudiencePath, nil
}

// ServiceForAudience resolves a canonical resource audience back to its
// stable service identity. The URL must use this catalog's configured base;
// route aliases and audiences from another environment are rejected.
func (c *Catalog) ServiceForAudience(resourceAudience string) (ServiceID, error) {
	if c == nil {
		return "", errors.New("service catalog is required")
	}
	resourceAudience = strings.TrimSpace(resourceAudience)
	for serviceID, definition := range definitions {
		if resourceAudience == c.baseURL+definition.AudiencePath {
			return serviceID, nil
		}
	}
	return "", fmt.Errorf("resource audience %q is not registered", resourceAudience)
}

func normalizeBaseURL(value string) (string, error) {
	value = strings.TrimSuffix(strings.TrimSpace(value), "/")
	if value == "" {
		return "", errors.New("OAuth2 audience base URL is required")
	}
	if strings.Contains(value, "%") {
		return "", errors.New("OAuth2 audience base URL must not be percent encoded")
	}
	parsed, err := url.Parse(value)
	if err != nil {
		return "", fmt.Errorf("parse OAuth2 audience base URL: %w", err)
	}
	if parsed.Scheme != "https" || parsed.Host == "" {
		return "", errors.New("OAuth2 audience base URL must be an absolute HTTPS URL")
	}
	if parsed.User != nil || parsed.Port() != "" || parsed.RawQuery != "" || parsed.ForceQuery || parsed.Fragment != "" {
		return "", errors.New("OAuth2 audience base URL must not contain user information, a port, query, or fragment")
	}
	if parsed.Path != "" && path.Clean(parsed.Path) != parsed.Path {
		return "", errors.New("OAuth2 audience base URL path is not canonical")
	}
	parsed.Host = strings.ToLower(parsed.Hostname())
	parsed.RawPath = ""
	return strings.TrimSuffix(parsed.String(), "/"), nil
}
