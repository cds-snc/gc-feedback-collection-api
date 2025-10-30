# AWS Infrastructure Architecture

## Overview
Feedback collection API migrated from Azure Functions (C#) to AWS Lambda (Python).

## Architecture Diagram

```
┌─────────────┐         ┌──────────────┐
│ SES Email   │────────▶│ SNS Topics   │
└─────────────┘         └──────┬───────┘
                               │
┌─────────────┐                │         ┌──────────────┐
│ Web Forms   │────────────────┼────────▶│ API Gateway  │
└─────────────┘                │         └──────┬───────┘
                               │                │
                               ▼                ▼
                        ┌──────────────────────────┐
                        │   Lambda Functions (6)   │
                        │  - queue_problem         │
                        │  - queue_problem_form    │
                        │  - queue_toptask         │
                        │  - queue_toptask_survey_ │
                        │    form                  │
                        │  - problem_commit        │
                        │  - top_task_survey_      │
                        │    commit                │
                        └───────────┬──────────────┘
                                    │
                        ┌───────────┴──────────┐
                        ▼                      ▼
                ┌──────────────┐      ┌──────────────┐
                │ SQS Problem  │      │ SQS TopTask  │
                │    Queue     │      │    Queue     │
                └──────┬───────┘      └──────┬───────┘
                       │                     │
                       └──────────┬──────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │   EventBridge Scheduler    │
                    │   (triggers every 2 min)   │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │   Commit Lambda Functions  │
                    └─────────────┬──────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │      DocumentDB Cluster    │
                    │  - problem collection      │
                    │  - originalproblem         │
                    │  - toptasksurvey           │
                    └────────────────────────────┘
```

## AWS Services

| Service | Purpose | Quantity |
|---------|---------|----------|
| **Lambda** | Serverless compute | 6 functions |
| **SQS** | Message queuing | 2 queues + 2 DLQs |
| **API Gateway** | REST API endpoints | 4 POST endpoints |
| **SES** | Inbound email | 2 email addresses |
| **SNS** | Email notifications | 2 topics |
| **DocumentDB** | MongoDB-compatible DB | 1 cluster |
| **EventBridge** | Scheduled triggers | 2 rules |
| **Secrets Manager** | Credentials storage | 1 secret |
| **CloudWatch** | Logging & monitoring | Per service |

## API Endpoints

```
POST /problem/email           → queue_problem Lambda
POST /problem/form            → queue_problem_form Lambda
POST /toptask/email           → queue_toptask Lambda
POST /toptask/survey/form     → queue_toptask_survey_form Lambda
```

## Email Configuration

**SES Inbound:**
- `problems@feedback.canada.gc.ca` → SNS → queue_problem Lambda
- `surveys@feedback.canada.gc.ca` → SNS → queue_toptask Lambda

## Processing Flow

### Problem Feedback:
1. **Input**: Web form POST or email
2. **Queue**: Lambda → SQS problem-queue
3. **Process**: EventBridge triggers `problem_commit` every 2 min
4. **Store**: DocumentDB `problem` + `originalproblem` collections

### TopTask Survey:
1. **Input**: Web form POST or email
2. **Queue**: Lambda → SQS toptask-queue
3. **Process**: EventBridge triggers `top_task_survey_commit` every 2 min
4. **Store**: DocumentDB `toptasksurvey` collection

## Environment Variables

```bash
# MongoDB
MONGO_URL=docdb-cluster.xyz.documentdb.amazonaws.com
MONGO_PORT=27017
MONGO_DB=pagesuccess
MONGO_USERNAME=<from-secrets-manager>
MONGO_PASSWORD=<from-secrets-manager>
ENVIRONMENT=production

# SQS
PROBLEM_QUEUE_URL=https://sqs.ca-central-1.amazonaws.com/xxx/problem-queue
TOPTASK_QUEUE_URL=https://sqs.ca-central-1.amazonaws.com/xxx/toptask-queue
```

## Security

- **VPC**: Lambda functions in private subnets (for DocumentDB access)
- **IAM**: Least privilege roles per function
- **Secrets**: Stored in Secrets Manager, not environment variables
- **API Auth**: API Gateway with API keys or IAM authorization
- **Encryption**: DocumentDB TLS required, data encrypted at rest

## Deployment Checklist

- [ ] VPC with private subnets
- [ ] DocumentDB cluster
- [ ] Secrets Manager configuration
- [ ] SQS queues + DLQs
- [ ] Lambda functions (6)
- [ ] Lambda layers (dependencies)
- [ ] API Gateway REST API
- [ ] SES domain verification
- [ ] SES receipt rules + SNS topics
- [ ] EventBridge schedules
- [ ] IAM roles and policies
- [ ] CloudWatch alarms
- [ ] Data migration from CosmosDB
