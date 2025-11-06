# Local Testing Guide

Test the GC Feedback Collection API locally using AWS SAM and Docker.

## Prerequisites

- **Docker Desktop** - [Download](https://www.docker.com/products/docker-desktop)
- **AWS SAM CLI** - `brew install aws-sam-cli`
- **Python 3.11** - `python3 --version`

## Architecture

**Production (AWS):**

- **Forms:** Web Form → API Gateway → Lambda → SQS → EventBridge (2min) → Commit Lambda → DocumentDB
- **Emails:** SES Email → SNS → Lambda → SQS → EventBridge (2min) → Commit Lambda → DocumentDB

**Local (Docker):**

- **Forms:** curl → API Gateway (SAM) → Lambda → ElasticMQ → Manual API → MongoDB
- **Emails (mock):** curl → API Gateway (SAM) → Lambda → ElasticMQ → Manual API → MongoDB

**Key Differences:**

- Production has two input paths (API Gateway + SES/SNS); local uses API Gateway for both
- Production auto-processes queues every 2 minutes; local requires manual trigger

## Quick Start

```bash
cd local_testing
chmod +x start-local-mock-infrastructure.sh test-local-mock-infrastructure.sh

# Start services
./start-local-mock-infrastructure.sh

# Test in another terminal
./test-local-mock-infrastructure.sh
```

## Manual Testing

### Problem Feedback

**Form:**

```bash
curl -X POST http://localhost:3000/problem/form \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "submissionPage=https://www.canada.ca/taxes" \
  -d "details=Test problem" \
  -d "helpful=no"
```

**Email (mock SES/SNS):**

```bash
curl -X POST http://localhost:3000/problem/email \
  -H "Content-Type: text/plain" \
  -d "2025-11-06;CRA;taxes;filing;File taxes;https://www.canada.ca/taxes;No;404;Page error"
```

### Top Task Survey

**Form:**

```bash
curl -X POST http://localhost:3000/toptask/survey/form \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "dateTime=2025-11-06T20:30:00Z" \
  -d "language=en" \
  -d "satisfaction=5" \
  -d "ease=4"
```

**Email (mock SES/SNS with ~!~ delimiter):**

```bash
curl -X POST http://localhost:3000/toptask/email \
  -H "Content-Type: text/plain" \
  -d "2025-11-06T20:30:00Z~!~https://www.canada.ca~!~en~!~Desktop~!~Yes~!~ESDC~!~Benefits~!~~!~EI~!~Apply~!~~!~~!~~!~~!~~!~~!~4~!~3~!~Yes~!~Yes~!~Confusing~!~~!~~!~email:gc:ca"
```

### Process Queues

```bash
curl -X POST http://localhost:3000/admin/process-problems
curl -X POST http://localhost:3000/admin/process-toptasks
```

## MongoDB Access

```bash
# Connect
docker exec -it gc-feedback-mongodb mongosh -u admin -p password --authenticationDatabase admin pagesuccess

# Query collections
db.problem.find().pretty()
db.toptasksurvey.find().pretty()

# Count records
db.problem.countDocuments()
db.toptasksurvey.countDocuments()

# Clear data
db.problem.deleteMany({})
db.originalproblem.deleteMany({})
db.toptasksurvey.deleteMany({})
```

## Troubleshooting

```bash
# Check services
docker ps

# View logs
docker logs gc-feedback-mongodb
docker logs gc-feedback-sqs

# Restart services
docker-compose restart

# Port conflict
lsof -ti:3000 | xargs kill -9

# Rebuild
sam build --use-container

# Check ElasticMQ queues
curl http://localhost:9325/queues
```

## Local vs AWS

| Component  | Production         | Local                    |
| ---------- | ------------------ | ------------------------ |
| Email      | SES → SNS → Lambda | HTTP POST (mock)         |
| SQS        | AWS SQS            | ElasticMQ (Docker)       |
| Scheduling | EventBridge (2min) | Manual API calls         |
| Database   | DocumentDB (TLS)   | MongoDB (Docker, no TLS) |
| API/Lambda | AWS managed        | SAM + Docker             |

## Cleanup

```bash
# Stop SAM: Ctrl+C in running terminal
docker-compose down -v
docker network rm gc-feedback-network
```

## Resources

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [ElasticMQ (Local SQS)](https://github.com/softwaremill/elasticmq)
- [Architecture Documentation](../architecture.md)
