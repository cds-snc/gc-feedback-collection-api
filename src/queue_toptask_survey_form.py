"""
QueueTopTaskSurveyForm Lambda Function
Handles POST requests from TopTask survey forms and queues data.

Converted from: QueueTopTaskSurveyForm/run.csx
Trigger: API Gateway (POST) - Survey form submission (use API Gateway auth instead of JWT)
Output: SQS Queue message

Note: JWT authentication removed - use AWS API Gateway IAM/API Key authentication instead
"""

import json
import logging
import os
import boto3
from typing import Dict, Any
from urllib.parse import parse_qs

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SQS client
sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get('TOPTASK_QUEUE_URL', '')


def parse_form_data(body: str, content_type: str = '') -> Dict[str, Any]:
    """
    Parse form data from request body.
    
    Args:
        body: Request body
        content_type: Content-Type header
        
    Returns:
        Dictionary of form fields
    """
    if 'application/json' in content_type:
        return json.loads(body)
    else:
        # Parse URL-encoded form data
        parsed = parse_qs(body)
        # Convert list values to single strings
        return {k: v[0] if isinstance(v, list) and len(v) > 0 else v for k, v in parsed.items()}


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for QueueTopTaskSurveyForm function.
    
    Args:
        event: API Gateway event containing survey form data
        context: Lambda context
        
    Returns:
        API Gateway response
    """
    try:
        # Parse request body
        body = event.get('body', '')
        if event.get('isBase64Encoded', False):
            import base64
            body = base64.b64decode(body).decode('utf-8')
        
        headers = event.get('headers', {})
        content_type = headers.get('Content-Type', '') or headers.get('content-type', '')
        
        # Parse form data or JSON
        survey_data = parse_form_data(body, content_type)
        
        # Convert to JSON string for queue
        json_data = json.dumps(survey_data, indent=2)
        logger.info(json_data)
        
        logger.info("Trying to add to queue")
        
        # Send to SQS queue
        response = sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json_data
        )
        
        logger.info(f"Data queued successfully. MessageId: {response['MessageId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data received.'})
        }
        
    except Exception as e:
        logger.error(f"Error processing survey form: {str(e)}", exc_info=True)
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Bad data....'})
        }
