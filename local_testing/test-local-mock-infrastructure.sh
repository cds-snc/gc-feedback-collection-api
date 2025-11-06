#!/bin/bash
# Comprehensive test script for local SAM setup
# Tests all 6 API endpoints

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="http://localhost:3000"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing GC Feedback Collection API${NC}"
echo -e "${GREEN}All 6 Endpoints${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Test 1: Submit problem form (web form)
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Test 1: Problem Form Submission${NC}"
echo -e "${BLUE}========================================${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/problem/form" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15" \
  -d "submissionPage=https://www.canada.ca/en/services/benefits/ei.html" \
  -d "pageTitle=Employment Insurance" \
  -d "language=en" \
  -d "institutionopt=ESDC" \
  -d "themeopt=benefits" \
  -d "sectionopt=employment" \
  -d "problem=Other" \
  -d "details=The form doesn't work on mobile" \
  -d "helpful=No" \
  -d "oppositelang=/fr/services/benefits/ei.html" \
  -d "contact=test@example.com")
echo "$RESPONSE"
echo -e "${GREEN}✓ Problem form submitted${NC}"
echo ""

# Test 2: Submit problem email (email webhook)
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Test 2: Problem Email Webhook${NC}"
echo -e "${BLUE}========================================${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/problem/email" \
  -H "Content-Type: text/plain" \
  -d "2025-11-04;CRA;taxes;filing;File your taxes;https://www.canada.ca/en/services/taxes/income-tax.html;No;404;Page not found error")
echo "$RESPONSE"
echo -e "${GREEN}✓ Problem email submitted${NC}"
echo ""

# Test 3: Submit TopTask survey form (web form)
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Test 3: TopTask Survey Form${NC}"
echo -e "${BLUE}========================================${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/toptask/survey/form" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  -d "dateTime=2025-11-04T20:30:00Z" \
  -d "surveyReferrer=https://www.canada.ca/en.html" \
  -d "language=en" \
  -d "device=Desktop" \
  -d "screener=Yes" \
  -d "dept1=CRA" \
  -d "theme1=Taxes" \
  -d "themeOther1=" \
  -d "grouping1=Income Tax" \
  -d "task1=File taxes" \
  -d "taskOther1=" \
  -d "dept2=" \
  -d "theme2=" \
  -d "grouping2=" \
  -d "task2=" \
  -d "taskOther2=" \
  -d "satisfaction=5" \
  -d "ease=4" \
  -d "completion=Yes" \
  -d "improve=Yes" \
  -d "improveComment=Better mobile support needed" \
  -d "whyNot=" \
  -d "whyNotComment=" \
  -d "sampling=invitation:gc:canada:taxes:cra:income:file")
echo "$RESPONSE"
echo -e "${GREEN}✓ TopTask survey form submitted${NC}"
echo ""

# Test 4: Submit TopTask email (email webhook with delimiter)
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Test 4: TopTask Email Webhook${NC}"
echo -e "${BLUE}========================================${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/toptask/email" \
  -H "Content-Type: text/plain" \
  -d "2025-11-04T20:30:00Z~!~https://www.canada.ca/en.html~!~en~!~Desktop~!~Yes~!~ESDC~!~Benefits~!~~!~EI~!~Apply for benefits~!~~!~~!~~!~~!~~!~~!~4~!~3~!~Yes~!~Yes~!~Application process is confusing~!~~!~~!~email:gc:canada:benefits:esdc:ei:apply")
echo "$RESPONSE"
echo -e "${GREEN}✓ TopTask email submitted${NC}"
echo ""

# Wait for messages to be in queue
echo -e "${YELLOW}Waiting 2 seconds for messages to be queued...${NC}"
sleep 2
echo ""

# Test 5: Process problem queue (commit to MongoDB)
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Test 5: Process Problem Queue${NC}"
echo -e "${BLUE}========================================${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/admin/process-problems" \
  -H "Content-Type: application/json")
echo "$RESPONSE"
echo -e "${GREEN}✓ Problem queue processed${NC}"
echo ""

# Test 6: Process TopTask queue (commit to MongoDB)
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Test 6: Process TopTask Queue${NC}"
echo -e "${BLUE}========================================${NC}"
RESPONSE=$(curl -s -X POST "$API_URL/admin/process-toptasks" \
  -H "Content-Type: application/json")
echo "$RESPONSE"
echo -e "${GREEN}✓ TopTask queue processed${NC}"
echo ""

# Verify MongoDB data
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Verifying Data in MongoDB${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Problem records count:${NC}"
PROBLEM_COUNT=$(docker exec gc-feedback-mongodb mongosh -u admin -p password \
  --authenticationDatabase admin pagesuccess --quiet \
  --eval "db.problem.countDocuments()")
echo "  $PROBLEM_COUNT records"
echo ""

echo -e "${YELLOW}Original problem records count:${NC}"
ORIG_COUNT=$(docker exec gc-feedback-mongodb mongosh -u admin -p password \
  --authenticationDatabase admin pagesuccess --quiet \
  --eval "db.originalproblem.countDocuments()")
echo "  $ORIG_COUNT records"
echo ""

echo -e "${YELLOW}TopTask survey records count:${NC}"
TOPTASK_COUNT=$(docker exec gc-feedback-mongodb mongosh -u admin -p password \
  --authenticationDatabase admin pagesuccess --quiet \
  --eval "db.toptasksurvey.countDocuments()")
echo "  $TOPTASK_COUNT records"
echo ""

# Show sample records
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Sample Records${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Latest Problem Record:${NC}"
docker exec gc-feedback-mongodb mongosh -u admin -p password \
  --authenticationDatabase admin pagesuccess --quiet \
  --eval "db.problem.find().sort({_id: -1}).limit(1).pretty()"
echo ""

echo -e "${YELLOW}Latest TopTask Record:${NC}"
docker exec gc-feedback-mongodb mongosh -u admin -p password \
  --authenticationDatabase admin pagesuccess --quiet \
  --eval "db.toptasksurvey.find().sort({_id: -1}).limit(1).pretty()"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  ✓ Tested all 6 API endpoints"
echo "  ✓ Problem records in MongoDB: $PROBLEM_COUNT"
echo "  ✓ TopTask records in MongoDB: $TOPTASK_COUNT"
echo ""
echo -e "${YELLOW}To view all data in MongoDB:${NC}"
echo "  docker exec -it gc-feedback-mongodb mongosh -u admin -p password --authenticationDatabase admin pagesuccess"
echo ""
echo -e "${YELLOW}Useful queries:${NC}"
echo "  db.problem.find().pretty()"
echo "  db.originalproblem.find().pretty()"
echo "  db.toptasksurvey.find().pretty()"
echo "  db.problem.countDocuments()"
echo "  db.toptasksurvey.countDocuments()"
echo ""
