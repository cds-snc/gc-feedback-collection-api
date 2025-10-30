"""
TopTaskSurveyCommit Lambda Function
Processes SQS queue messages and commits TopTask survey data to MongoDB.

Converted from: TopTaskSurveyCommit/run.csx
Trigger: EventBridge (scheduled) or SQS trigger
Output: MongoDB writes to 'toptasksurvey' collection
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
from models import TopTask

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get('TOPTASK_QUEUE_URL', '')

# MongoDB configuration
MONGO_URL = os.environ.get('MONGO_URL', '')
MONGO_PORT = int(os.environ.get('MONGO_PORT', '27017'))
MONGO_DB = os.environ.get('MONGO_DB', 'pagesuccess')
MONGO_USERNAME = os.environ.get('MONGO_USERNAME', '')
MONGO_PASSWORD = os.environ.get('MONGO_PASSWORD', '')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'production')

# Processing configuration
TIMES_TO_LOOP = 100


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


def parse_toptask_data(top_task_data: list) -> Optional[TopTask]:
    """
    Parse TopTask data array into TopTask object.
    
    Args:
        top_task_data: List of TopTask field values
        
    Returns:
        TopTask object or None if parsing fails
    """
    data_length = len(top_task_data)
    
    if data_length != 24:
        logger.warning(f"Expected data length 24, got {data_length}")
        return None
    
    try:
        toptask = TopTask()
        
        logger.info("Data retrieved has length of 24.")
        
        toptask.time_stamp = top_task_data[0]
        toptask.date_time = top_task_data[0]
        toptask.survey_referrer = top_task_data[1]
        toptask.language = top_task_data[2]
        toptask.device = top_task_data[3]
        toptask.screener = top_task_data[4]
        
        # Check if Department is not empty for task 1 and is empty for task 2
        # Set task 1 data
        dept_task1 = top_task_data[5]
        dept_task2 = top_task_data[11]
        
        if (dept_task1 and dept_task1 not in [' / ', '']) and (not dept_task2 or dept_task2 in [' / ', '']):
            toptask.dept = top_task_data[5]
            toptask.theme = top_task_data[6]
            toptask.theme_other = top_task_data[7]
            logger.info(f"Theme Other: {toptask.theme_other}")
            toptask.grouping = top_task_data[8]
            toptask.task = top_task_data[9]
            toptask.task_other = top_task_data[10]
            logger.info("Entry is Task 1")
        
        # Check if Department is not empty for task 2. Set task 2 data.
        if dept_task2 and dept_task2 not in [' / ', '']:
            toptask.dept = top_task_data[11]
            toptask.theme = top_task_data[12]
            toptask.theme_other = top_task_data[7]
            logger.info(f"Theme Other: {toptask.theme_other}")
            toptask.grouping = top_task_data[13]
            toptask.task = top_task_data[14]
            toptask.task_other = top_task_data[15]
            logger.info("Entry is Task 2")
        
        toptask.task_satisfaction = top_task_data[16]
        toptask.task_ease = top_task_data[17]
        toptask.task_completion = top_task_data[18]
        toptask.task_improve = top_task_data[19]
        toptask.task_improve_comment = top_task_data[20]
        toptask.task_why_not = top_task_data[21]
        toptask.task_why_not_comment = top_task_data[22]
        toptask.task_sampling = top_task_data[23]
        
        # Parse sampling data
        top_task_sampling = top_task_data[23].split(':')
        
        if len(top_task_sampling) == 7:
            toptask.sampling_invitation = top_task_sampling[0]
            toptask.sampling_gc = top_task_sampling[1]
            toptask.sampling_canada = top_task_sampling[2]
            toptask.sampling_theme = top_task_sampling[3]
            toptask.sampling_institution = top_task_sampling[4]
            toptask.sampling_grouping = top_task_sampling[5]
            toptask.sampling_task = top_task_sampling[6]
        else:
            toptask.sampling_invitation = ""
            toptask.sampling_gc = ""
            toptask.sampling_canada = ""
            toptask.sampling_theme = ""
            toptask.sampling_institution = ""
            toptask.sampling_grouping = ""
            toptask.sampling_task = ""
        
        # Set processing flags
        toptask.processed = "false"
        toptask.top_task_air_table_sync = "false"
        toptask.personal_info_processed = "false"
        toptask.auto_tag_processed = "false"
        
        # Format date & timestamps
        try:
            # Parse datetime string and format
            dt = datetime.fromisoformat(toptask.date_time.replace('Z', '+00:00'))
            toptask.date_time = dt.strftime('%Y-%m-%d')
            logger.info(f"Date converted to: {toptask.date_time}")
            
            toptask.time_stamp = dt.strftime('%H:%M')
            logger.info(f"Timestamp converted to: {toptask.time_stamp}")
        except Exception as e:
            logger.warning(f"Error parsing datetime: {str(e)}")
            # Keep original values if parsing fails
        
        return toptask
        
    except Exception as e:
        logger.error(f"Error parsing TopTask data: {str(e)}", exc_info=True)
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
    toptasks_collection = database['toptasksurvey']
    
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
                    
                    # Remove HTML tags
                    decoded_string = decoded_string.replace('<html><body><pre>', '')
                    decoded_string = decoded_string.replace('</pre></body></html>', '')
                    
                    # HTML decode
                    decoded_string = unescape(decoded_string)
                    
                    logger.info(f"Decoded string: {decoded_string}")
                    
                    # Split by delimiter "~!~"
                    top_task_data = decoded_string.split('~!~')
                    logger.info(f"Data size: {len(top_task_data)}")
                    
                    # Parse TopTask data
                    toptask = parse_toptask_data(top_task_data)
                    
                    if toptask:
                        # Insert into MongoDB
                        result = toptasks_collection.insert_one(toptask.to_dict())
                        logger.info(f"Records saved. TopTask ID: {result.inserted_id}")
                        
                        times_looped += 1
                        
                        # Delete message from queue
                        sqs.delete_message(
                            QueueUrl=QUEUE_URL,
                            ReceiptHandle=receipt_handle
                        )
                        logger.info("The email data has been dequeued.")
                    else:
                        logger.info("Data length is not 24 or parsing failed")
                    
                except PyMongoError as e:
                    logger.error(f"MongoDB error: {str(e)}", exc_info=True)
                except Exception as e:
                    logger.error(f"Error processing message: {str(e)}", exc_info=True)
        
    finally:
        client.close()
    
    elapsed_time = (time.time() - start_time) * 1000  # Convert to milliseconds
    return times_looped, elapsed_time


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for TopTaskSurveyCommit function.
    
    Args:
        event: EventBridge scheduled event or SQS trigger
        context: Lambda context
        
    Returns:
        Response with processing statistics
    """
    try:
        logger.info("Starting TopTaskSurveyCommit processing...")
        
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
        logger.error(f"Error in TopTaskSurveyCommit: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
