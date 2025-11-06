# Local Testing Guide

This guide explains how to test the GC Feedback Collection API locally using AWS SAM before deploying to AWS.

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Docker Desktop** - For running containers locally
   - [Download Docker Desktop](https://www.docker.com/products/docker-desktop)
2. **AWS SAM CLI** - For local Lambda testing

   ```bash
   # Install via Homebrew (macOS)
   brew install aws-sam-cli

   # Or use pip
   pip install aws-sam-cli
   ```

3. **Python 3.11** - Required for Lambda runtime
   ```bash
   # Check your Python version
   python3 --version
   ```

## Architecture Overview

The local setup replicates the AWS infrastructure:

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│ HTTP POST   │────────▶│ API Gateway  │────────▶│   Lambda     │
│ (curl/form) │         │ (SAM Local)  │         │  Functions   │
└─────────────┘         └──────────────┘         └──────┬───────┘
                                                          │
                                                          ▼
                                                   ┌──────────────┐
                                                   │  SQS Queues  │
                                                   │   (Local)    │
                                                   └──────┬───────┘
                                                          │
                                                          ▼
                                                   ┌──────────────┐
                                                   │Commit Lambda │
                                                   └──────┬───────┘
                                                          │
                                                          ▼
                                                   ┌──────────────┐
                                                   │   MongoDB    │
                                                   │  (Docker)    │
                                                   └──────────────┘
```

## Quick Start

### 1. Start Everything with One Command

```bash
chmod +x start-local.sh test-local.sh
./start-local.sh
```

This script will:

- ✅ Check for required tools (Docker, SAM CLI)
- ✅ Create necessary Docker network
- ✅ Start MongoDB container
- ✅ Build SAM application
- ✅ Start API Gateway locally on port 3000

### 2. Test the API (In Another Terminal)

Once the API is running, open a new terminal and run:

```bash
./test-local.sh
```

This will:

- Submit a problem form
- Submit a top task survey
- Process both queues (commit to MongoDB)
- Display record counts in MongoDB

## Manual Testing

### Submit Problem Feedback

```bash
curl -X POST http://localhost:3000/problem/form \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "submissionPage=https://www.canada.ca/en/services/taxes.html" \
  -d "pageTitle=Taxes" \
  -d "language=en" \
  -d "institutionopt=CRA" \
  -d "themeopt=taxes" \
  -d "sectionopt=filing" \
  -d "problem=other" \
  -d "details=Test problem feedback" \
  -d "helpful=no" \
  -d "contact="
```

### Submit Top Task Survey

```bash
curl -X POST http://localhost:3000/toptask/survey/form \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "surveyReferrer=https://www.canada.ca/en.html" \
  -d "language=en" \
  -d "screener=yes" \
  -d "dept=ESDC" \
  -d "theme=jobs" \
  -d "task=find-job" \
  -d "taskSatisfaction=satisfied" \
  -d "taskEase=easy" \
  -d "taskCompletion=yes" \
  -d "taskImprove=Could be better" \
  -d "taskSampling=Voluntary"
```

### Process Queues (Commit to MongoDB)

```bash
# Process problem queue
curl -X POST http://localhost:3000/admin/process-problems

# Process top task queue
curl -X POST http://localhost:3000/admin/process-toptasks
```

## Available Endpoints

| Endpoint                  | Method | Description                                |
| ------------------------- | ------ | ------------------------------------------ |
| `/problem/form`           | POST   | Submit problem feedback form               |
| `/problem/email`          | POST   | Webhook for email-based problem feedback   |
| `/toptask/survey/form`    | POST   | Submit top task survey form                |
| `/toptask/email`          | POST   | Webhook for email-based surveys            |
| `/admin/process-problems` | POST   | Manually trigger problem queue processing  |
| `/admin/process-toptasks` | POST   | Manually trigger top task queue processing |

## MongoDB Access

### Connect to MongoDB

```bash
docker exec -it gc-feedback-mongodb mongosh pagesuccess
```

### View Collections

```javascript
// In MongoDB shell
db.problem.find().pretty();
db.originalproblem.find().pretty();
db.toptasksurvey.find().pretty();
```

### Count Records

```bash
docker exec gc-feedback-mongodb mongosh pagesuccess --quiet --eval "db.problem.countDocuments()"
docker exec gc-feedback-mongodb mongosh pagesuccess --quiet --eval "db.toptasksurvey.countDocuments()"
```

### Clear All Data

```bash
docker exec gc-feedback-mongodb mongosh pagesuccess --quiet --eval "db.problem.deleteMany({})"
docker exec gc-feedback-mongodb mongosh pagesuccess --quiet --eval "db.originalproblem.deleteMany({})"
docker exec gc-feedback-mongodb mongosh pagesuccess --quiet --eval "db.toptasksurvey.deleteMany({})"
```

## Configuration

### Environment Variables

The local setup uses these default values (configured in `template.yaml`):

```yaml
MONGO_URL: host.docker.internal
MONGO_PORT: 27017
MONGO_DB: pagesuccess
MONGO_USERNAME: admin
MONGO_PASSWORD: password
ENVIRONMENT: staging
```

### Changing Configuration

Edit `samconfig.toml` to modify parameters:

```toml
parameter_overrides = "MongoUrl=host.docker.internal MongoPort=27017 ..."
```

## Troubleshooting

### MongoDB Connection Issues

If you see "connection refused" errors:

```bash
# Check if MongoDB is running
docker ps | grep mongodb

# View MongoDB logs
docker logs gc-feedback-mongodb

# Restart MongoDB
docker-compose restart mongodb
```

### SAM Build Fails

```bash
# Clean and rebuild
sam build --use-container

# If Docker issues persist
docker system prune -a
```

### SQS Queue Not Working

SAM Local uses in-memory queues. Messages only persist while the API is running. To test queue processing:

1. Submit data via API endpoints
2. Messages are added to in-memory SQS
3. Call admin endpoints to process queues
4. Data is written to MongoDB

### Port Already in Use

If port 3000 is already in use:

1. Edit `samconfig.toml` and change the port
2. Or stop the conflicting service:
   ```bash
   lsof -ti:3000 | xargs kill -9
   ```

## Differences from AWS

| Feature     | AWS                | Local (SAM)       |
| ----------- | ------------------ | ----------------- |
| SQS         | Persistent queues  | In-memory queues  |
| EventBridge | Scheduled triggers | Manual API calls  |
| DocumentDB  | Managed service    | Docker MongoDB    |
| API Gateway | Fully managed      | SAM emulation     |
| Lambda      | Isolated execution | Docker containers |

## Next Steps

After testing locally:

1. **Review Logs**: Check CloudWatch-style logs in terminal
2. **Verify Data**: Query MongoDB to ensure data is correct
3. **Test Edge Cases**: Try invalid inputs, missing fields, etc.
4. **Performance Testing**: Test with multiple concurrent requests
5. **Deploy to AWS**: Once satisfied, deploy with Terraform/CloudFormation

## Clean Up

### Stop API Server

Press `Ctrl+C` in the terminal running SAM

### Stop MongoDB

```bash
docker-compose down
```

### Remove All Containers and Data

```bash
docker-compose down -v
docker network rm gc-feedback-network
```

## Additional Resources

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [SAM Local Testing](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-test-and-debug.html)
- [MongoDB Docker Image](https://hub.docker.com/_/mongo)
- [Architecture Documentation](./architecture.md)
