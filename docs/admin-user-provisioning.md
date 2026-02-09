# Admin User Provisioning — Product Requirements

## Summary

Replace the current manual Auth0 process for managing admin users with an in-app
admin screen. This is important for operational efficiency and will become more
pressing as the contributor base grows with the Western Hemisphere expansion.

## Current State

- Admin user management is done manually through the Auth0 dashboard
- Only a small number of people can do it
- The existing Users screen in the admin UI shows users but lacks provisioning controls

## Requirements

- **Superadmin-only access**: Only superadmins can manage other users
- **Extends existing Users screen**: Build on what's already there
- **Capabilities**:
  - Invite new admin users
  - Remove admin users
  - Assign and change roles
- **Backed by Auth0 APIs**: Operations go through Auth0's management API
- **Audit trail**: Track who provisioned/deprovisioned whom and when

## Notes

- This is independent of the Western Hemisphere expansion and can be scheduled
  separately
- However, expanding geographic coverage will likely bring new contributors who
  need admin access, making this more urgent over time
