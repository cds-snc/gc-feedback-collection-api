"""
ProblemCommit Lambda Function
Processes SQS queue messages and commits problem feedback to MongoDB.

Converted from: ProblemCommit/run.csx
Trigger: EventBridge (scheduled) or SQS trigger
Output: MongoDB writes to 'problem' and 'originalproblem' collections
"""

import json
import logging
import os
import time
import base64
import boto3
from datetime import datetime
from typing import Dict, Any, Optional
from pymongo import MongoClient
from pymongo.errors import PyMongoError
from html import unescape
from models import Problem, OriginalProblem

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get('PROBLEM_QUEUE_URL', '')

# MongoDB configuration
MONGO_URL = os.environ.get('MONGO_URL', '')
MONGO_PORT = int(os.environ.get('MONGO_PORT', '27017'))
MONGO_DB = os.environ.get('MONGO_DB', 'pagesuccess')
MONGO_USERNAME = os.environ.get('MONGO_USERNAME', '')
MONGO_PASSWORD = os.environ.get('MONGO_PASSWORD', '')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'production')

# Processing configuration
TIMES_TO_LOOP = 100


class WidgetAllFieldsEnum:
    """Enum for AEM forms with all fields filled."""
    TIMESTAMP = 0
    DATE = 1
    URL = 2
    LANG = 3
    OPPOSITE_LANG = 4
    TITLE = 5
    INSTITUTION = 6
    THEME = 7
    SECTION = 8
    PROBLEM = 9
    PROBLEM_DETAILS = 10
    YESNO = 11
    DEVICE = 12
    BROWSER = 13
    CONTACT = 14


class WidgetEmailVersionEnum:
    """Enum for email version widget."""
    DATE = 0
    INSTITUTION = 1
    THEME = 2
    SECTION = 3
    TITLE = 4
    URL = 5
    YESNO = 6
    PROBLEM = 7
    PROBLEM_DETAILS = 8


def init_mongo_client() -> MongoClient:
    """
    Initialize MongoDB client with proper authentication.
    
    Returns:
        Configured MongoClient instance
    """
    if ENVIRONMENT == 'staging':
        # Staging environment without authentication
        client = MongoClient(MONGO_URL, MONGO_PORT)
    else:
        # Production with TLS and authentication
        connection_string = f"mongodb://{MONGO_USERNAME}:{MONGO_PASSWORD}@{MONGO_URL}:{MONGO_PORT}/{MONGO_DB}?tls=true&tlsAllowInvalidCertificates=true&retryWrites=false&authSource={MONGO_DB}&authMechanism=SCRAM-SHA-1"
        client = MongoClient(connection_string)
    
    return client


def parse_problem_data(problem_data: list, data_length: int) -> Optional[Problem]:
    """
    Parse problem data array into Problem object.
    
    Args:
        problem_data: List of problem field values
        data_length: Length of the data array
        
    Returns:
        Problem object or None if parsing fails
    """
    problem = Problem()
    
    try:
        if data_length == 15:
            # Widget with all fields filled
            problem.time_stamp = problem_data[WidgetAllFieldsEnum.TIMESTAMP]
            problem.problem_date = problem_data[WidgetAllFieldsEnum.DATE]
            problem.url = problem_data[WidgetAllFieldsEnum.URL]
            problem.language = problem_data[WidgetAllFieldsEnum.LANG]
            problem.opposite_lang = problem_data[WidgetAllFieldsEnum.OPPOSITE_LANG]
            problem.title = problem_data[WidgetAllFieldsEnum.TITLE]
            problem.institution = problem_data[WidgetAllFieldsEnum.INSTITUTION]
            problem.theme = problem_data[WidgetAllFieldsEnum.THEME]
            problem.section = problem_data[WidgetAllFieldsEnum.SECTION]
            problem.problem = problem_data[WidgetAllFieldsEnum.PROBLEM]
            problem.problem_details = problem_data[WidgetAllFieldsEnum.PROBLEM_DETAILS]
            problem.yesno = problem_data[WidgetAllFieldsEnum.YESNO]
            problem.device_type = problem_data[WidgetAllFieldsEnum.DEVICE]
            problem.browser = problem_data[WidgetAllFieldsEnum.BROWSER]
            problem.contact = problem_data[WidgetAllFieldsEnum.CONTACT]
            problem.data_origin = "POST-REQUEST-WIDGET_ALL_FIELDS"
            
        elif data_length == 9:
            # Email version (old AEM format)
            problem.institution = problem_data[WidgetEmailVersionEnum.INSTITUTION].upper().strip()
            problem.theme = problem_data[WidgetEmailVersionEnum.THEME].lower().strip()
            problem.section = problem_data[WidgetEmailVersionEnum.SECTION].lower().strip()
            problem.problem_date = datetime.utcnow().strftime('%Y-%m-%d')
            problem.time_stamp = datetime.utcnow().strftime('%H:%M')
            problem.title = problem_data[WidgetEmailVersionEnum.TITLE]
            problem.url = problem_data[WidgetEmailVersionEnum.URL]
            problem.yesno = problem_data[WidgetEmailVersionEnum.YESNO]
            problem.problem = problem_data[WidgetEmailVersionEnum.PROBLEM]
            problem.problem_details = problem_data[WidgetEmailVersionEnum.PROBLEM_DETAILS]
            problem.data_origin = "EMAIL-VERSION-AEM-(OLD)"
        else:
            logger.warning(f"Unexpected data length: {data_length}")
            return None
        
        # Detect language from URL
        url_lower = problem.url.lower()
        if '/en/' in url_lower or 'travel.gc.ca' in url_lower:
            problem.language = 'en'
        if '/fr/' in url_lower or 'voyage.gc.ca' in url_lower:
            problem.language = 'fr'
        
        # Set processing flags
        problem.processed = 'false'
        problem.air_table_sync = 'false'
        problem.personal_info_processed = 'false'
        problem.auto_tag_processed = 'false'
        
        return problem
        
    except IndexError as e:
        logger.error(f"Error parsing problem data: {str(e)}")
        return None


def process_queue_messages() -> tuple:
    """
    Process messages from SQS queue and write to MongoDB.
    
    Returns:
        Tuple of (messages_processed, elapsed_time_ms)
    """
    start_time = time.time()
    times_looped = 0
    
    # Initialize MongoDB client
    client = init_mongo_client()
    logger.info("MongoDB client initialized...")
    
    database = client[MONGO_DB]
    problems_collection = database['problem']
    orig_problems_collection = database['originalproblem']
    
    try:
        for index in range(TIMES_TO_LOOP):
            # Receive messages from queue
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=0
            )
            
            messages = response.get('Messages', [])
            
            if not messages:
                logger.info("No more messages in queue")
                break
            
            for message in messages:
                try:
                    # Get message body
                    message_body = message['Body']
                    receipt_handle = message['ReceiptHandle']
                    
                    # Decode if base64 encoded
                    try:
                        decoded_string = base64.b64decode(message_body).decode('utf-8')
                    except Exception:
                        decoded_string = message_body
                    
                    logger.info(f"Before HTML decode: {decoded_string}")
                    
                    # HTML decode
                    decoded_string = unescape(decoded_string)
                    
                    # Split by semicolon
                    problem_data = decoded_string.split(';')
                    data_length = len(problem_data)
                    logger.info(f"Data size: {data_length}")
                    
                    # Parse problem data
                    problem = parse_problem_data(problem_data, data_length)
                    
                    if problem:
                        # Check if problem has comment
                        if not problem.problem_details or problem.problem_details.strip() == '':
                            logger.info("Problem has no comment. Problem will be disregarded.")
                        else:
                            # Insert into MongoDB
                            result = problems_collection.insert_one(problem.to_dict())
                            logger.info(f"Records saved. Problem ID: {result.inserted_id}")
                            
                            # Save original record
                            orig_problem = OriginalProblem.from_problem(problem)
                            orig_problems_collection.insert_one(orig_problem.to_dict())
                            logger.info("Original record has been saved.")
                        
                        times_looped += 1
                        
                        # Delete message from queue
                        sqs.delete_message(
                            QueueUrl=QUEUE_URL,
                            ReceiptHandle=receipt_handle
                        )
                        logger.info("The email data has been dequeued.")
                    
                except PyMongoError as e:
                    logger.error(f"MongoDB error: {str(e)}")
                except Exception as e:
                    logger.error(f"Error processing message: {str(e)}", exc_info=True)
        
    finally:
        client.close()
    
    elapsed_time = (time.time() - start_time) * 1000  # Convert to milliseconds
    return times_looped, elapsed_time


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for ProblemCommit function.
    
    Args:
        event: EventBridge scheduled event or SQS trigger
        context: Lambda context
        
    Returns:
        Response with processing statistics
    """
    try:
        logger.info("Starting ProblemCommit processing...")
        
        times_looped, elapsed_ms = process_queue_messages()
        
        logger.info("-------------------------------")
        logger.info(f"Time elapsed for {times_looped} entries: {elapsed_ms}ms")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'messages_processed': times_looped,
                'elapsed_time_ms': elapsed_ms
            })
        }
        
    except Exception as e:
        logger.error(f"Error in ProblemCommit: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
