# GC Feedback Collection API - Local Testing

Test the full AWS Lambda workflow locally using AWS SAM and Docker before deploying to AWS.

## Quick Start

```bash
# Start everything
./start-local-mock-infrastructure.sh

# Test in another terminal
./test-local-mock-infrastructure.sh
```

## API Endpoints (http://localhost:3000)

| Endpoint                       | Purpose                         |
| ------------------------------ | ------------------------------- |
| `POST /problem/form`           | Submit problem feedback (form)  |
| `POST /problem/email`          | Submit problem feedback (email) |
| `POST /toptask/survey/form`    | Submit top task survey (form)   |
| `POST /toptask/email`          | Submit top task survey (email)  |
| `POST /admin/process-problems` | Process problem queue           |
| `POST /admin/process-toptasks` | Process top task queue          |

## Architecture

### Production (AWS)

- **Forms:** Web Form → API Gateway → Lambda → SQS → EventBridge → Commit Lambda → DocumentDB
- **Emails:** SES Email → SNS → Lambda → SQS → EventBridge → Commit Lambda → DocumentDB

### Local (Docker)

- **Forms:** curl → API Gateway (SAM) → Lambda → ElasticMQ → Manual API → MongoDB
- **Emails (mock):** curl → API Gateway (SAM) → Lambda → ElasticMQ → Manual API → MongoDB

**Key Difference:** Production has two distinct input paths (API Gateway for forms, SES/SNS for emails); local uses API Gateway for both.

## Testing Example

```bash
# Submit problem feedback
curl -X POST http://localhost:3000/problem/form \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "submissionPage=https://www.canada.ca/taxes" \
  -d "details=Test feedback" \
  -d "helpful=no"

# Process queue
curl -X POST http://localhost:3000/admin/process-problems

# Verify
docker exec gc-feedback-mongodb mongosh -u admin -p password --authenticationDatabase admin pagesuccess --quiet --eval "db.problem.find().pretty()"
```

## MongoDB Access

```bash
# Connect
docker exec -it gc-feedback-mongodb mongosh -u admin -p password --authenticationDatabase admin pagesuccess

# Count records
db.problem.countDocuments()
db.toptasksurvey.countDocuments()

# Clear data
db.problem.deleteMany({})
db.toptasksurvey.deleteMany({})
```

## Key Differences from AWS

| Component      | Production         | Local              |
| -------------- | ------------------ | ------------------ |
| **Email**      | SES → SNS → Lambda | HTTP POST (mock)   |
| **SQS**        | AWS SQS            | ElasticMQ (Docker) |
| **Scheduling** | EventBridge (2min) | Manual API calls   |
| **Database**   | DocumentDB (TLS)   | MongoDB (no TLS)   |
| **API/Lambda** | AWS managed        | SAM + Docker       |

## Troubleshooting

```bash
# Check containers
docker ps

# View logs
docker logs gc-feedback-mongodb
docker logs gc-feedback-sqs

# Restart services
docker-compose restart

# Port conflict
lsof -ti:3000 | xargs kill -9

# Clean rebuild
sam build --use-container
```

## Cleanup

```bash
# Stop everything
docker-compose down -v
docker network rm gc-feedback-network
```

## Next Steps

1. ✅ Test locally with various inputs
2. ☐ Build Terraform for AWS infrastructure
3. ☐ Deploy to AWS staging environment
4. ☐ Configure SES email ingestion
5. ☐ Test end-to-end in AWS

See [LOCAL_TESTING.md](./LOCAL_TESTING.md) for detailed testing guide.
