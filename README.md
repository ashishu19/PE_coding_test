# PE_coding_test
Repository for PE coding test
## Components

### Part 1 — Sumo Logic Monitoring
- Query filters logs for `/api/data` endpoint responses exceeding 3 seconds
- Scheduled search runs every 15 minutes across a 15 minute log window
- Alert triggers when more than 5 slow requests are detected
- Alert fires a webhook to API Gateway when threshold is exceeded

### Part 2 — AWS Lambda Function
- Python 3.11 Lambda function triggered by Sumo Logic webhook via API Gateway
- Checks EC2 instance state before attempting restart
- Stops instance and waits for full stop using boto3 waiters
- Starts instance and waits until running before returning
- Logs all actions to CloudWatch
- Sends SNS notification on success or failure

### Part 3 — Infrastructure as Code
- Terraform provisions all AWS resources repeatably
- Resources created: VPC, subnet, EC2, Lambda, SNS, API Gateway, IAM roles, CloudWatch log group
- IAM roles follow least privilege — scoped to specific resource ARNs
- Environment variables used throughout — no hardcoded values
