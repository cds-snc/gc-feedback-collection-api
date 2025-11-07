# AWS Lambda Python Functions - Converted from Azure Functions C#

This directory contains the converted Python Lambda functions for the GC Feedback Collection API.

## Project Structure

```
src/
├── models.py                    # Data models (Problem, TopTask)
├── db_utils.py                  # MongoDB connection utilities
├── queue_problem.py             # Email webhook → Problem queue
├── queue_problem_form.py        # Form POST → Problem queue
├── problem_commit.py            # Problem queue → MongoDB
├── queue_toptask.py                # Email webhook → TopTask queue
├── queue_toptask_survey_form.py   # Survey form POST → TopTask queue
└── top_task_survey_commit.py      # TopTask queue → MongoDB
```

## Functions Overview

### 1. **queue_problem.py**
- **Trigger**: SNS (from SES inbound email)
- **Purpose**: Parse inbound emails containing problem feedback
- **Output**: SQS queue message
- **Original**: `QueueProblem/run.csx`

### 2. **queue_problem_form.py**
- **Trigger**: API Gateway (POST) - Form submission
- **Purpose**: Handle form submissions with device detection
- **Output**: SQS queue message
- **Original**: `QueueProblemForm/run.csx`

### 3. **problem_commit.py**
- **Trigger**: EventBridge (scheduled) or SQS
- **Purpose**: Process queued messages and write to MongoDB
- **Output**: MongoDB `problem` and `originalproblem` collections
- **Original**: `ProblemCommit/run.csx`

### 4. **queue_toptask.py**
- **Trigger**: SNS (from SES inbound email)
- **Purpose**: Parse survey emails with device detection
- **Output**: SQS queue message
- **Original**: `QueueTopTask/run.csx`

### 5. **queue_toptask_survey_form.py**
- **Trigger**: API Gateway (POST) - Form submission
- **Purpose**: Handle survey form submissions and queue data
- **Output**: SQS queue message
- **Original**: `QueueTopTaskSurveyForm/run.csx`

### 6. **top_task_survey_commit.py**
- **Trigger**: EventBridge (scheduled) or SQS
- **Purpose**: Process survey queue and write to MongoDB
- **Output**: MongoDB `toptasksurvey` collection
- **Original**: `TopTaskSurveyCommit/run.csx`

## Environment Variables

All functions require the following environment variables:

### MongoDB Configuration
```bash
MONGO_URL=your-mongodb-host
MONGO_PORT=27017
MONGO_DB=pagesuccess
MONGO_USERNAME=your-username
MONGO_PASSWORD=your-password
ENVIRONMENT=production  # or staging
```

### Queue Configuration
```bash
PROBLEM_QUEUE_URL=https://sqs.region.amazonaws.com/account/problem-queue
TOPTASK_QUEUE_URL=https://sqs.region.amazonaws.com/account/toptask-queue
```



## Key Changes from C# to Python

### 1. **Queue System**
- **Azure**: Azure Storage Queues with `ICollector<string>`
- **AWS**: SQS with `boto3.client('sqs')`

### 2. **Triggers**
- **Azure**: HTTP triggers with bindings
- **AWS**: API Gateway events, EventBridge schedules

### 3. **Email Service**
- **Azure**: SendGrid inbound webhooks
- **AWS**: SES inbound → SNS → Lambda

### 4. **Authentication**
- **Azure**: `AuthorizationLevel.Anonymous`
- **AWS**: API Gateway IAM roles or API keys

### 5. **Error Handling**
- Improved Python exception handling
- Structured logging with context

### 6. **Data Models**
- **C#**: Classes with attributes
- **Python**: Dataclasses with `to_dict()` methods

## Business Logic Preserved

All critical business logic has been maintained:

✅ **Device Detection**: User-Agent parsing with regex patterns  
✅ **Email Parsing**: SES email parsing via SNS  
✅ **Data Sanitization**: Semicolon replacement, HTML decoding  
✅ **Validation**: Required field checks, data quality  
✅ **Language Detection**: URL-based language inference  
✅ **Theme Extraction**: `/services/` URL parsing  
✅ **MongoDB Operations**: Connection pooling, error handling  
✅ **Queue Processing**: Batch processing with configurable limits  

## Deployment

See `architecture.md` in the root directory for complete AWS infrastructure plan and deployment checklist.

## Dependencies

See `requirements.txt` for all Python dependencies:
- boto3: AWS SDK
- pymongo: MongoDB driver
- python-multipart: Form data parsing
- python-http-client: HTTP utilities

## Notes

- Connection pooling is implemented for MongoDB (Lambda warm starts)
- All functions use UTC timezone for consistency
- Logging follows CloudWatch Logs best practices
- Error handling includes detailed context for debugging
