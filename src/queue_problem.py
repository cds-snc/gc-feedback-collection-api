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
import boto3
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SQS client
sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get('PROBLEM_QUEUE_URL', '')


def parse_ses_email(sns_message: Dict[str, Any]) -> str:
    """
    Parse SES email from SNS notification.
    
    Args:
        sns_message: SNS message containing SES email data
        
    Returns:
        Email content text
    """
    # SES via SNS sends email content in 'content' field
    # Or in mail object depending on receipt rule configuration
    if 'content' in sns_message:
        return sns_message['content']
    elif 'mail' in sns_message:
        # Extract from mail object
        return sns_message.get('mail', {}).get('commonHeaders', {}).get('subject', '')
    return ''


def sanitize_text(text: str) -> str:
    """
    Sanitize email text by replacing semicolons after 8th occurrence.
    
    Args:
        text: Email text content
        
    Returns:
        Sanitized text with semicolons replaced after 8th occurrence
    """
    parts = text.split(';', 8)
    
    if len(parts) >= 9:
        # Sanitize the part after the 8th semicolon
        parts[8] = parts[8].replace(';', ':')
        # Reconstruct the text
        text = ';'.join(parts)
    
    return text


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for QueueProblem function triggered by SNS from SES.
    
    Args:
        event: SNS event containing SES email data
        context: Lambda context
        
    Returns:
        Success response
    """
    try:
        logger.info("Email received from SES via SNS.")
        
        # Parse SNS message
        # SNS wraps the SES message in a Records array
        for record in event.get('Records', []):
            if record.get('EventSource') == 'aws:sns':
                sns_message = json.loads(record['Sns']['Message'])
                
                # Extract email content from SES message
                # SES provides the email in 'content' or 'mail' object
                text = ''
                
                # Try to get the email body from content
                if 'content' in sns_message:
                    text = sns_message['content']
                # Or extract from mail object
                elif 'mail' in sns_message and 'commonHeaders' in sns_message['mail']:
                    # For SES, the actual email body might be in S3 or passed directly
                    # This is a simplified version - adjust based on SES receipt rule config
                    text = str(sns_message)
                
                logger.info("Email parsed from SES.")
                
                # Sanitize the text
                text = sanitize_text(text)
                
                logger.info(f"Problem Queue Item: {text}")
                
                # Send to SQS queue
                response = sqs.send_message(
                    QueueUrl=QUEUE_URL,
                    MessageBody=text
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
