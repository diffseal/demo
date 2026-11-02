# Acme fulfillment: a Diffseal demo

A made-up service's Terraform. Each open pull request shows one kind of change, and the Diffseal comment on it is the real output. Nothing here runs against AWS.

## What is in it

- `infra/modules/fulfillment/main.tf`: an S3 bucket, an SQS queue with a dead-letter queue, a DynamoDB table, the Lambda function and its IAM role.
- `infra/envs/prod/fulfillment/main.tf`: the production root that calls the module.
- `.github/workflows/diffseal.yml`: runs Diffseal on every pull request and on pushes to `main`. It comments on the pull request and uploads the change record to the Diffseal evidence service.

## The three pull requests

| Branch | The change | Result |
| :-- | :-- | :-- |
| `pr/replace-database` | Keys the shipments table by `tracking_number` instead of `shipment_id` | BLOCK. Changing `hash_key` replaces the table, and the items in it are lost |
| `pr/broaden-iam-policy` | Lets the Lambda role use every DynamoDB action on every resource | REVIEW. `dynamodb:*` on `*` fails the least privilege check, which cites ISO 27001 A.5.15 and SOC 2 CC6.3 |
| `pr/harmless-change` | Raises the Lambda timeout from 15 to 30 seconds | PASS. One in-place update |

## Run it yourself

You need Node 18 or later and a clone of this repository. Diffseal reads the git history only. It needs no AWS credentials and does not run `terraform`.

```bash
git clone https://github.com/diffseal/demo.git && cd demo
git fetch origin 'refs/heads/pr/*:refs/heads/pr/*'

# Review one pull request's commit against main
npx diffseal@beta replay --repo . --commit pr/replace-database --base main --out-dir ../demo-runs
```

Diffseal never writes inside the repository it reads, so `replay` puts its reports in `../demo-runs`. Exit code 2 means the change was blocked.
