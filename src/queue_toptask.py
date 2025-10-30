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
sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get('TOPTASK_QUEUE_URL', '')


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
    if 'content' in sns_message:
        return sns_message['content']
    elif 'mail' in sns_message:
        return str(sns_message)
    return ''


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for QueueTopTask function triggered by SNS from SES.
    
    Args:
        event: SNS event containing SES email data
        context: Lambda context
        
    Returns:
        Success response
    """
    try:
        logger.info("Email received from SES via SNS.")
        
        # Note: Device detection from User-Agent not available in SNS/SES flow
        # User-Agent would need to be extracted from email headers if needed
        device_type = "Unknown"
        logger.info(f"Device Type: {device_type}")
        
        # Parse SNS message
        for record in event.get('Records', []):
            if record.get('EventSource') == 'aws:sns':
                sns_message = json.loads(record['Sns']['Message'])
                
                logger.info("Email parsed from SES.")
                
                # Extract email content
                html_text = parse_ses_email(sns_message)
                
                # Replace semicolons with "; " to preserve data structure
                html_text = html_text.replace(';', '; ')
                
                logger.info(f"TopTask Queue Item: {html_text}")
                
                # Send to SQS queue
                response = sqs.send_message(
                    QueueUrl=QUEUE_URL,
                    MessageBody=html_text
                )
                
                logger.info(f"Data queued successfully. MessageId: {response['MessageId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'OK'})
        }
        
    except Exception as e:
        logger.error(f"Error processing email: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
