# Repository settings record

Repository: `dana/ainulindale-infra`

Generated at: `2026-06-30T19:16:21Z`

## Repository summary

{"defaultBranchRef":{"name":"main"},"deleteBranchOnMerge":false,"mergeCommitAllowed":true,"nameWithOwner":"dana/ainulindale-infra","rebaseMergeAllowed":true,"squashMergeAllowed":true,"url":"https://github.com/dana/ainulindale-infra","visibility":"PUBLIC"}

## Rulesets

[{"_links":{"html":{"href":"https://github.com/dana/ainulindale-infra/rules/18332265"},"self":{"href":"https://api.github.com/repos/dana/ainulindale-infra/rulesets/18332265"}},"created_at":"2026-06-30T12:14:14.284-07:00","enforcement":"active","id":18332265,"name":"main requires PR and strict baseline check","node_id":"RRS_lACqUmVwb3NpdG9yec5MnZARzgEXumk","source":"dana/ainulindale-infra","source_type":"Repository","target":"branch","updated_at":"2026-06-30T12:14:14.328-07:00"}]

## Selected active ruleset details

{"_links":{"html":{"href":"https://github.com/dana/ainulindale-infra/rules/18332265"},"self":{"href":"https://api.github.com/repos/dana/ainulindale-infra/rulesets/18332265"}},"bypass_actors":[],"conditions":{"ref_name":{"exclude":[],"include":["refs/heads/main"]}},"created_at":"2026-06-30T12:14:14.284-07:00","current_user_can_bypass":"never","enforcement":"active","id":18332265,"name":"main requires PR and strict baseline check","node_id":"RRS_lACqUmVwb3NpdG9yec5MnZARzgEXumk","rules":[{"parameters":{"allowed_merge_methods":["merge","squash","rebase"],"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_approving_review_count":0,"required_review_thread_resolution":false,"required_reviewers":[]},"type":"pull_request"},{"parameters":{"do_not_enforce_on_create":false,"required_status_checks":[{"context":"repository-baseline"}],"strict_required_status_checks_policy":true},"type":"required_status_checks"},{"type":"non_fast_forward"},{"type":"deletion"}],"source":"dana/ainulindale-infra","source_type":"Repository","target":"branch","updated_at":"2026-06-30T12:14:14.328-07:00"}

## Security and analysis

{"dependabot_security_updates":{"status":"enabled"},"secret_scanning":{"status":"enabled"},"secret_scanning_non_provider_patterns":{"status":"disabled"},"secret_scanning_push_protection":{"status":"enabled"},"secret_scanning_validity_checks":{"status":"disabled"}}

## Dependabot security updates

{"enabled":true,"paused":false}
