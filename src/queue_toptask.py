"""
QueueTopTask Lambda Function
Parses SES inbound emails via SNS for TopTask survey data with device detection.

Converted from: QueueTopTask/run.csx
Trigger: SNS (from SES inbound email)
Output: SQS Queue message
"""

import json
import logging
import os
import re
import boto3
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SQS client
ENVIRONMENT = os.environ.get("ENVIRONMENT", "production")
QUEUE_URL = os.environ.get("TOPTASK_QUEUE_URL", "")

# Configure SQS client with local endpoint for local development
if ENVIRONMENT == "local":
    # Extract endpoint from QUEUE_URL for local testing
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


def detect_device_type(user_agent: str) -> str:
    """
    Detect device type from User-Agent string.

    Args:
        user_agent: User-Agent header string

    Returns:
        Device type: 'Mobile', 'Tablet', 'Desktop', or 'Unknown'
    """
    if not user_agent:
        return "Unknown"

    # Define regex patterns for device types
    mobile_pattern = r"(iPhone|Android.*Mobile|Windows Phone)"
    tablet_pattern = r"(iPad|Android(?!.*Mobile)|Tablet)"
    desktop_pattern = r"(Windows NT|Macintosh|Linux)"

    # Check device type using regex
    if re.search(mobile_pattern, user_agent, re.IGNORECASE):
        return "Mobile"
    elif re.search(tablet_pattern, user_agent, re.IGNORECASE):
        return "Tablet"
    elif re.search(desktop_pattern, user_agent, re.IGNORECASE):
        return "Desktop"

    return "Unknown"


def parse_ses_email(sns_message: Dict[str, Any]) -> str:
    """
    Parse SES email from SNS notification.

    Args:
        sns_message: SNS message containing SES email data

    Returns:
        Email HTML content
    """
    # Extract email content from SES message
    if "content" in sns_message:
        return sns_message["content"]
    elif "mail" in sns_message:
        return str(sns_message)
    return ""


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for QueueTopTask function.
    Handles both SNS events (from SES) and direct POST requests (for testing).

    Args:
        event: SNS event containing SES email data or API Gateway event
        context: Lambda context

    Returns:
        Success response
    """
    try:
        html_text = None

        # Check if this is an SNS event (production) or direct POST (testing)
        if "Records" in event and len(event.get("Records", [])) > 0:
            # SNS event from SES
            logger.info("Email received from SES via SNS.")

            for record in event.get("Records", []):
                if record.get("EventSource") == "aws:sns":
                    sns_message = json.loads(record["Sns"]["Message"])
                    logger.info("Email parsed from SES.")

                    # Extract email content
                    html_text = parse_ses_email(sns_message)
        else:
            # Direct POST request (local testing)
            logger.info("Direct POST request received (local testing).")

            # Get body from API Gateway event
            body = event.get("body", "")
            if event.get("isBase64Encoded", False):
                import base64

                body = base64.b64decode(body).decode("utf-8")

            html_text = body

        if html_text:
            # Replace semicolons with "; " to preserve data structure (if not using delimiter)
            # Note: Don't replace if already using ~!~ delimiter
            if "~!~" not in html_text:
                html_text = html_text.replace(";", "; ")

            logger.info(f"TopTask Queue Item: {html_text}")

            # Send to SQS queue
            response = sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=html_text)

            logger.info(f"Data queued successfully. MessageId: {response['MessageId']}")
        else:
            logger.warning("No content to queue")

        return {"statusCode": 200, "body": json.dumps({"message": "OK"})}

    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"}),
        }
