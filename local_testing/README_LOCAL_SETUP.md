# GC Feedback Collection API - Local Testing Setup

This repository now includes a complete local testing environment using AWS SAM and Docker, allowing you to test the full AWS Lambda workflow locally before deploying to AWS.

## Quick Start

```bash
# 1. Start the local environment (MongoDB + SAM API)
./start-local.sh

# 2. In another terminal, run the test suite
./test-local.sh
```

## What's Included

### Files Created

- **`template.yaml`** - SAM template defining all Lambda functions, API Gateway, and SQS queues
- **`docker-compose.yml`** - MongoDB and ElasticMQ (local SQS) configuration
- **`samconfig.toml`** - SAM CLI configuration for local testing
- **`start-local.sh`** - One-command startup script
- **`test-local.sh`** - Automated test suite
- **`scripts/init-mongo.js`** - MongoDB initialization script
- **`scripts/elasticmq.conf`** - Local SQS queue configuration
- **`test-events/problem-form.json`** - Sample test event
- **`LOCAL_TESTING.md`** - Comprehensive testing documentation
- **`.gitignore`** - Git ignore file for build artifacts

### API Endpoints (Local)

All available at `http://localhost:3000`:

| Endpoint                       | Purpose                                   |
| ------------------------------ | ----------------------------------------- |
| `POST /problem/form`           | Submit problem feedback (form submission) |
| `POST /problem/email`          | Submit problem feedback (email webhook)   |
| `POST /toptask/survey/form`    | Submit top task survey                    |
| `POST /toptask/email`          | Submit top task email                     |
| `POST /admin/process-problems` | Manually process problem queue → MongoDB  |
| `POST /admin/process-toptasks` | Manually process top task queue → MongoDB |

### Local Infrastructure

```
┌─────────────────────────────────────────────┐
│  Your Machine (localhost)                   │
│                                             │
│  ┌─────────────────┐                       │
│  │ API Gateway     │  :3000                │
│  │ (SAM Local)     │                       │
│  └────────┬────────┘                       │
│           │                                 │
│           ▼                                 │
│  ┌─────────────────┐                       │
│  │ Lambda Functions│                       │
│  │ - queue_*       │                       │
│  │ - *_commit      │                       │
│  └────────┬────────┘                       │
│           │                                 │
│           ▼                                 │
│  ┌─────────────────┐                       │
│  │ SQS Queues      │  (in-memory)          │
│  │ - problem-queue │                       │
│  │ - toptask-queue │                       │
│  └────────┬────────┘                       │
│           │                                 │
│           ▼                                 │
│  ┌─────────────────┐                       │
│  │ MongoDB         │  :27017               │
│  │ (Docker)        │                       │
│  │ - problem       │                       │
│  │ - toptasksurvey │                       │
│  └─────────────────┘                       │
└─────────────────────────────────────────────┘
```

## Workflow Testing

The local setup replicates the production flow:

1. **Submit Data** → HTTP POST to API endpoints
2. **Queue** → Lambda functions write to SQS
3. **Process** → Commit functions read from SQS (manual trigger for local)
4. **Store** → Data written to MongoDB collections

## Example: Testing Problem Feedback Flow

```bash
# Terminal 1: Start the environment
./start-local.sh

# Terminal 2: Test the flow
# Step 1: Submit a problem form
curl -X POST http://localhost:3000/problem/form \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "submissionPage=https://www.canada.ca/en/services/taxes.html" \
  -d "pageTitle=Taxes" \
  -d "language=en" \
  -d "institutionopt=CRA" \
  -d "details=Test feedback" \
  -d "helpful=no"

# Step 2: Process the queue (writes to MongoDB)
curl -X POST http://localhost:3000/admin/process-problems

# Step 3: Verify in MongoDB
docker exec gc-feedback-mongodb mongosh pagesuccess --quiet \
  --eval "db.problem.find().pretty()"
```

## MongoDB Access

```bash
# Connect to MongoDB shell
docker exec -it gc-feedback-mongodb mongosh pagesuccess

# View data
db.problem.find().pretty()
db.toptasksurvey.find().pretty()

# Count records
db.problem.countDocuments()
db.toptasksurvey.countDocuments()

# Clear all data
db.problem.deleteMany({})
db.originalproblem.deleteMany({})
db.toptasksurvey.deleteMany({})
```

## Key Differences from AWS

| Aspect          | AWS Production                | Local (SAM)            |
| --------------- | ----------------------------- | ---------------------- |
| **API Gateway** | Managed service               | SAM emulation          |
| **Lambda**      | Isolated functions            | Docker containers      |
| **SQS**         | Persistent queues             | ElasticMQ (persistent) |
| **EventBridge** | Scheduled triggers (2 min)    | Manual API calls       |
| **DocumentDB**  | Managed cluster               | MongoDB Docker         |
| **Networking**  | VPC, subnets, security groups | Docker network         |

## Important Notes

### SQS Queues

- Local setup uses **ElasticMQ** - a lightweight SQS-compatible message queue running in Docker
- Messages persist in ElasticMQ until processed (similar to AWS SQS)
- In production, EventBridge triggers commit functions every 2 minutes
- Locally, you must **manually trigger** commits via the admin endpoints (`/admin/process-problems` and `/admin/process-toptasks`)

### MongoDB vs DocumentDB

- Local: Standard MongoDB 7.0 (simpler, no TLS required)
- Production: DocumentDB (MongoDB-compatible, TLS required)
- The code handles both via the `ENVIRONMENT` variable

### Network Configuration

- `host.docker.internal` allows Lambda containers to reach MongoDB
- Both services run on the same Docker network: `gc-feedback-network`

## Stopping the Environment

```bash
# Stop SAM (in terminal running start-local.sh)
Ctrl+C

# Stop MongoDB
docker-compose down

# Clean up everything (including data volumes)
docker-compose down -v
docker network rm gc-feedback-network
```

## Troubleshooting

### "Connection refused" errors

```bash
# Check MongoDB status
docker ps | grep mongodb

# View MongoDB logs
docker logs gc-feedback-mongodb

# Restart MongoDB
docker-compose restart mongodb
```

### Port 3000 already in use

```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9

# Or change the port in samconfig.toml
```

### SAM build fails

```bash
# Use container build (recommended)
sam build --use-container

# Or install dependencies locally
pip install -r requirements.txt -t .
```

## Next Steps

After successful local testing:

1. ✅ **Verify Data Quality** - Check MongoDB records are correct
2. ✅ **Test Edge Cases** - Invalid inputs, missing fields, special characters
3. ✅ **Performance Test** - Multiple concurrent requests
4. ☐ **Build Terraform** - Create infrastructure-as-code
5. ☐ **Deploy to AWS** - Use Terraform to deploy production environment
6. ☐ **Configure SES** - Set up email ingestion
7. ☐ **Test in AWS** - Verify end-to-end in cloud environment

## Additional Documentation

- [LOCAL_TESTING.md](./LOCAL_TESTING.md) - Detailed testing guide
- [architecture.md](./architecture.md) - AWS architecture overview
- [src/README.md](./src/README.md) - Lambda functions documentation

## Support

For issues or questions:

1. Check [LOCAL_TESTING.md](./LOCAL_TESTING.md) troubleshooting section
2. Review SAM CLI logs for error details
3. Verify Docker and MongoDB are running properly
