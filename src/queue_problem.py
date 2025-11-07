"""
QueueProblem Lambda Function
Parses SES inbound emails via SNS and queues problem feedback data.

Converted from: QueueProblem/run.csx
Trigger: SNS (from SES inbound email)
Output: SQS Queue message
"""

import json
import logging
import os
import email
import boto3
from typing import Dict, Any, Optional

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


def extract_email_text(sns_message: Dict[str, Any]) -> Optional[str]:
    """
    Extract text content from SES email delivered via SNS.
    SES sends the raw MIME email in the 'content' field.

    Args:
        sns_message: SNS message containing SES email data

    Returns:
        Plain text content from email body, or None if not found
    """
    try:
        # SES sends raw email content
        if "content" in sns_message:
            raw_email = sns_message["content"]

            # Parse the MIME message
            msg = email.message_from_string(raw_email)

            # Extract text/plain content
            if msg.is_multipart():
                for part in msg.walk():
                    content_type = part.get_content_type()
                    if content_type == "text/plain":
                        payload = part.get_payload(decode=True)
                        if payload:
                            return payload.decode("utf-8", errors="ignore")
            else:
                # Not multipart - get payload directly
                payload = msg.get_payload(decode=True)
                if payload:
                    return payload.decode("utf-8", errors="ignore")

        logger.warning("No email content found in SNS message")
        return None

    except Exception as e:
        logger.error(f"Error extracting email text: {str(e)}", exc_info=True)
        return None


def sanitize_text(text: str) -> str:
    """
    Sanitize email text by replacing semicolons after 8th occurrence.

    Args:
        text: Email text content

    Returns:
        Sanitized text with semicolons replaced after 8th occurrence
    """
    parts = text.split(";", 8)

    if len(parts) >= 9:
        # Sanitize the part after the 8th semicolon
        parts[8] = parts[8].replace(";", ":")
        # Reconstruct the text
        text = ";".join(parts)

    return text


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for QueueProblem function.
    Handles both SNS events (from SES) and direct POST requests (for testing).

    Args:
        event: SNS event containing SES email data or API Gateway event
        context: Lambda context

    Returns:
        Success response
    """
    try:
        text = None

        # Check if this is an SNS event (production) or direct POST (testing)
        if "Records" in event and len(event.get("Records", [])) > 0:
            # SNS event from SES
            logger.info("Email received from SES via SNS.")

            for record in event.get("Records", []):
                if record.get("EventSource") == "aws:sns":
                    sns_message = json.loads(record["Sns"]["Message"])
                    logger.info("Email parsed from SNS.")

                    # Extract text content from email
                    text = extract_email_text(sns_message)

                    if text:
                        break
        else:
            # Direct POST request (local testing)
            logger.info("Direct POST request received (local testing).")

            # Get body from API Gateway event
            body = event.get("body", "")
            if event.get("isBase64Encoded", False):
                import base64

                body = base64.b64decode(body).decode("utf-8")

            text = body

        if text:
            # Sanitize the text: replace semicolons after the 8th occurrence
            text = sanitize_text(text)

            logger.info(f"Problem Queue Item: {text}")

            # Send to SQS queue
            try:
                response = sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=text)
                logger.info(
                    f"Data queued successfully. MessageId: {response['MessageId']}"
                )
            except Exception as sqs_error:
                logger.error(
                    f"Failed to send message to SQS: {str(sqs_error)}", exc_info=True
                )
                raise
        else:
            logger.warning("No content to queue")

        return {"statusCode": 200, "body": json.dumps({"message": "OK"})}

    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"}),
        }
