"""
QueueProblemForm Lambda Function
Handles POST requests from problem feedback forms with device detection and validation.

Converted from: QueueProblemForm/run.csx
Trigger: API Gateway (POST) - Form submission endpoint
Output: SQS Queue message
"""

import json
import logging
import os
import re
import boto3
from datetime import datetime
from typing import Dict, Any, List
from urllib.parse import parse_qs

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SQS client
ENVIRONMENT = os.environ.get("ENVIRONMENT", "production")
QUEUE_URL = os.environ.get("PROBLEM_QUEUE_URL", "")

# Configure SQS client with local endpoint for local development
if ENVIRONMENT == "local":
    # Extract endpoint from QUEUE_URL for local testing
    # QUEUE_URL format: http://host.docker.internal:9324/000000000000/problem-queue
    import re

    match = re.match(r"(https?://[^/]+)", QUEUE_URL)
    endpoint = match.group(1) if match else "http://localhost:9324"

    sqs = boto3.client(
        "sqs",
        endpoint_url=endpoint,
        region_name="ca-central-1",
        aws_access_key_id="local",
        aws_secret_access_key="local",
    )
else:
    sqs = boto3.client("sqs")


def detect_device_and_browser(user_agent: str) -> tuple:
    """
    Detect device type and browser version from User-Agent string.

    Args:
        user_agent: User-Agent header string

    Returns:
        Tuple of (device_type, browser_version)
    """
    device_type = "Unknown"
    browser_version = "Unknown"

    if not user_agent:
        return device_type, browser_version

    # Device detection patterns
    device_pattern = (
        r"(iPad|iPhone|Android|Windows Phone|Windows NT|Linux|Macintosh|Windows)"
    )
    browser_pattern = r"(MSIE|Trident|Edge|Chrome|Firefox|Safari)(?:/([\d\.]+))?"

    device_match = re.search(device_pattern, user_agent, re.IGNORECASE)
    browser_match = re.search(browser_pattern, user_agent, re.IGNORECASE)

    if device_match:
        device_type = device_match.group(0)

    if browser_match:
        browser_version = browser_match.group(0)

    return device_type, browser_version


def parse_form_data(body: str, content_type: str = "") -> Dict[str, str]:
    """
    Parse form data from request body.

    Args:
        body: Request body
        content_type: Content-Type header

    Returns:
        Dictionary of form fields
    """
    if "application/json" in content_type:
        return json.loads(body)
    else:
        # Parse URL-encoded form data
        parsed = parse_qs(body)
        # Convert list values to single strings
        return {
            k: v[0] if isinstance(v, list) and len(v) > 0 else v
            for k, v in parsed.items()
        }


def extract_theme_from_url(submission_page: str) -> str:
    """
    Extract theme from submission page URL if it contains /services/.

    Args:
        submission_page: URL of the submission page

    Returns:
        Extracted theme or empty string
    """
    if "/services/" in submission_page:
        parts = submission_page.split("/services/")
        if len(parts) > 1:
            theme_parts = parts[1].split("/")
            if len(theme_parts) > 0:
                return theme_parts[0]
    return ""


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for QueueProblemForm function.

    Args:
        event: API Gateway event containing form submission
        context: Lambda context

    Returns:
        API Gateway response
    """
    try:
        logger.info(
            f"Date and time format: {datetime.utcnow().strftime('%Y-%m-%d %H:%M')}"
        )

        # Extract User-Agent header
        headers = event.get("headers", {})
        user_agent = headers.get("User-Agent", "") or headers.get("user-agent", "")

        # Detect device and browser
        device_type, browser_version = detect_device_and_browser(user_agent)
        logger.info(f"Device type: {device_type}, Browser version: {browser_version}")

        # Parse request body
        body = event.get("body", "")
        if event.get("isBase64Encoded", False):
            import base64

            body = base64.b64decode(body).decode("utf-8")

        content_type = headers.get("Content-Type", "") or headers.get(
            "content-type", ""
        )
        payload = parse_form_data(body, content_type)

        # Validate required fields
        required_fields = [
            "submissionPage",
            "pageTitle",
            "institutionopt",
            "details",
            "helpful",
        ]
        missing_fields = [field for field in required_fields if field not in payload]

        if missing_fields:
            logger.warning(f"Missing required fields: {', '.join(missing_fields)}")
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {"error": f"Missing required fields: {', '.join(missing_fields)}"}
                ),
            }

        # Extract and process form data
        time_stamp = datetime.utcnow().strftime("%H:%M")
        date = datetime.utcnow().strftime("%Y-%m-%d")

        submission_page = payload.get("submissionPage", "").replace(";", " ")
        language = payload.get("language", "")
        page_title = payload.get("pageTitle", "")
        institutionopt = payload.get("institutionopt", "").upper().strip()
        themeopt = payload.get("themeopt", "").lower().strip()
        sectionopt = payload.get("sectionopt", "").lower().strip()
        problem = payload.get("problem", "")
        details = payload.get("details", "").replace(";", "")
        helpful = payload.get("helpful", "")
        opposite_lang = payload.get("oppositelang", "")
        contact = payload.get("contact", "")

        # Extract theme from URL if submission page contains /services/
        if submission_page:
            extracted_theme = extract_theme_from_url(submission_page)
            if extracted_theme:
                themeopt = extracted_theme

        # Validate data quality
        if not details or details.strip() == "":
            logger.warning("Entry has no comment and will be disregarded.")
            return {
                "statusCode": 200,
                "body": json.dumps({"message": "Data received..."}),
            }

        if not page_title or not submission_page:
            logger.warning("Bad data...")
            return {"statusCode": 400, "body": json.dumps({"error": "Bad data...."})}

        # Create queue data string
        queue_data = f"{time_stamp};{date};{submission_page};{language};{opposite_lang};{page_title};{institutionopt};{themeopt};{sectionopt};{problem};{details};{helpful};{device_type};{browser_version};{contact}"

        queue_data_length = len(queue_data.split(";"))
        logger.info(f"Number of items in queueData: {queue_data_length}")
        logger.info(queue_data)

        # Send to SQS queue
        response = sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=queue_data)

        logger.info(f"Data queued successfully. MessageId: {response['MessageId']}")

        return {"statusCode": 200, "body": json.dumps({"message": "Data received..."})}

    except Exception as e:
        logger.error(f"Error processing form submission: {str(e)}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"}),
        }
