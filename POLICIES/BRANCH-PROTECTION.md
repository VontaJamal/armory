# Branch Protection Policy (main)

This is the required GitHub branch protection baseline for `main`.

## Required Settings

1. Require a pull request before merging.
2. Require at least 1 approval.
3. Dismiss stale approvals when new commits are pushed.
4. Require conversation resolution before merge.
5. Require status checks to pass before merging.
6. Do not allow force pushes.
7. Do not allow branch deletion.

## Required Status Checks

Configure these as required checks on `main`:

1. `catalog-validate`
2. `secret-hygiene`
3. `powershell-smoke`
4. `fixture-tests`
5. `release-validate`

## Recommended Extras

1. Require branches to be up to date before merging.
2. Restrict who can push to matching branches.
3. Enable merge queue for high-change periods.

## Operational Rule

If a required check is renamed in workflow files, update this policy and branch protection settings in the same pull request.
