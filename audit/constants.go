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

package audit

// ─────────────────────────────────────────────────────────────────────────────
// Common resource types
// ─────────────────────────────────────────────────────────────────────────────

const (
	// Core entities
	ResourceProfile      = "profile"
	ResourceContact      = "contact"
	ResourceAddress      = "address"
	ResourceRelationship = "relationship"

	// Organization hierarchy
	ResourceOrganization = "organization"
	ResourceOrgUnit      = "org_unit"
	ResourceDepartment   = "department"
	ResourcePosition     = "position"

	// Workforce
	ResourceWorkforceMember    = "workforce_member"
	ResourceTeam               = "team"
	ResourceTeamMembership     = "team_membership"
	ResourceAccessRole         = "access_role"
	ResourcePositionAssignment = "position_assignment"

	// Clients and groups
	ResourceClient      = "client"
	ResourceClientGroup = "client_group"
	ResourceMembership  = "membership"
	ResourceInvestor    = "investor"

	// Financial — Loans
	ResourceLoanProduct     = "loan_product"
	ResourceLoanAccount     = "loan_account"
	ResourceLoanRequest     = "loan_request"
	ResourceRepayment       = "repayment"
	ResourcePenalty         = "penalty"
	ResourceDisbursement    = "disbursement"
	ResourceLoanRestructure = "loan_restructure"
	ResourceReconciliation  = "reconciliation"

	// Financial — Savings
	ResourceSavingsProduct = "savings_product"
	ResourceSavingsAccount = "savings_account"
	ResourceDeposit        = "deposit"
	ResourceWithdrawal     = "withdrawal"

	// Financial — Funding
	ResourceInvestorAccount  = "investor_account"
	ResourceFundingAllocation = "funding_allocation"

	// Financial — Operations
	ResourceTransferOrder = "transfer_order"
	ResourcePayment       = "payment"

	// Field
	ResourceAgent              = "agent"
	ResourceClientRelationship = "client_relationship"

	// Settings and config
	ResourceFormTemplate   = "form_template"
	ResourceFormSubmission = "form_submission"

	// Geolocation
	ResourceArea  = "area"
	ResourceRoute = "route"
)

// ─────────────────────────────────────────────────────────────────────────────
// Common actions
// ─────────────────────────────────────────────────────────────────────────────

const (
	ActionCreate   = "create"
	ActionUpdate   = "update"
	ActionDelete   = "delete"
	ActionAdd      = "add"
	ActionRemove   = "remove"
	ActionSave     = "save"
	ActionApprove  = "approve"
	ActionReject   = "reject"
	ActionVerify   = "verify"
	ActionSubmit   = "submit"
	ActionCancel   = "cancel"
	ActionActivate = "activate"
	ActionSuspend  = "suspend"
	ActionMerge    = "merge"
	ActionTransfer = "transfer"
	ActionAssign   = "assign"
	ActionUnassign = "unassign"
)

// ─────────────────────────────────────────────────────────────────────────────
// Common relation actions
// ─────────────────────────────────────────────────────────────────────────────

const (
	RelationAdded    = "added"
	RelationRemoved  = "removed"
	RelationModified = "modified"
)
