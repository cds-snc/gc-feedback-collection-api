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
from pymongo.errors import PyMongoError
from html import unescape
from models import TopTask
from db_utils import MongoDBConnection

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
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

# Processing configuration
TIMES_TO_LOOP = 100


def parse_toptask_json(json_data: dict) -> Optional[TopTask]:
    """
    Parse TopTask JSON data (from form submission) into TopTask object.

    Args:
        json_data: Dictionary of TopTask field values from form

    Returns:
        TopTask object or None if parsing fails
    """
    try:
        toptask = TopTask()

        logger.info("Parsing JSON format (form submission)")

        # Extract form data
        toptask.time_stamp = json_data.get("dateTime", "")
        toptask.date_time = json_data.get("dateTime", "")
        toptask.survey_referrer = json_data.get("surveyReferrer", "")
        toptask.language = json_data.get("language", "")
        toptask.device = json_data.get("device", "")
        toptask.screener = json_data.get("screener", "")

        # Check task 1 and task 2 data
        dept1 = json_data.get("dept1", "")
        dept2 = json_data.get("dept2", "")

        # Set task 1 data if dept1 is present and dept2 is empty
        if dept1 and dept1 not in [" / ", ""] and (not dept2 or dept2 in [" / ", ""]):
            toptask.dept = dept1
            toptask.theme = json_data.get("theme1", "")
            toptask.theme_other = json_data.get("themeOther1", "")
            toptask.grouping = json_data.get("grouping1", "")
            toptask.task = json_data.get("task1", "")
            toptask.task_other = json_data.get("taskOther1", "")
            logger.info("Entry is Task 1")

        # Set task 2 data if dept2 is present
        if dept2 and dept2 not in [" / ", ""]:
            toptask.dept = dept2
            toptask.theme = json_data.get("theme2", "")
            toptask.theme_other = json_data.get("themeOther1", "")  # Shared field
            toptask.grouping = json_data.get("grouping2", "")
            toptask.task = json_data.get("task2", "")
            toptask.task_other = json_data.get("taskOther2", "")
            logger.info("Entry is Task 2")

        toptask.task_satisfaction = json_data.get("satisfaction", "")
        toptask.task_ease = json_data.get("ease", "")
        toptask.task_completion = json_data.get("completion", "")
        toptask.task_improve = json_data.get("improve", "")
        toptask.task_improve_comment = json_data.get("improveComment", "")
        toptask.task_why_not = json_data.get("whyNot", "")
        toptask.task_why_not_comment = json_data.get("whyNotComment", "")
        toptask.task_sampling = json_data.get("sampling", "")

        # Parse sampling data
        sampling_parts = toptask.task_sampling.split(":")
        if len(sampling_parts) == 7:
            toptask.sampling_invitation = sampling_parts[0]
            toptask.sampling_gc = sampling_parts[1]
            toptask.sampling_canada = sampling_parts[2]
            toptask.sampling_theme = sampling_parts[3]
            toptask.sampling_institution = sampling_parts[4]
            toptask.sampling_grouping = sampling_parts[5]
            toptask.sampling_task = sampling_parts[6]
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
            dt = datetime.fromisoformat(toptask.date_time.replace("Z", "+00:00"))
            toptask.date_time = dt.strftime("%Y-%m-%d")
            logger.info(f"Date converted to: {toptask.date_time}")
            toptask.time_stamp = dt.strftime("%H:%M")
            logger.info(f"Timestamp converted to: {toptask.time_stamp}")
        except Exception as e:
            logger.warning(f"Error parsing datetime: {str(e)}")

        return toptask

    except Exception as e:
        logger.error(f"Error parsing JSON TopTask data: {str(e)}", exc_info=True)
        return None


def parse_toptask_delimited(top_task_data: list) -> Optional[TopTask]:
    """
    Parse TopTask delimiter-separated data (from email) into TopTask object.

    Args:
        top_task_data: List of TopTask field values (24 fields)

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

        if (dept_task1 and dept_task1 not in [" / ", ""]) and (
            not dept_task2 or dept_task2 in [" / ", ""]
        ):
            toptask.dept = top_task_data[5]
            toptask.theme = top_task_data[6]
            toptask.theme_other = top_task_data[7]
            logger.info(f"Theme Other: {toptask.theme_other}")
            toptask.grouping = top_task_data[8]
            toptask.task = top_task_data[9]
            toptask.task_other = top_task_data[10]
            logger.info("Entry is Task 1")

        # Check if Department is not empty for task 2. Set task 2 data.
        if dept_task2 and dept_task2 not in [" / ", ""]:
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
        top_task_sampling = top_task_data[23].split(":")

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
            dt = datetime.fromisoformat(toptask.date_time.replace("Z", "+00:00"))
            toptask.date_time = dt.strftime("%Y-%m-%d")
            logger.info(f"Date converted to: {toptask.date_time}")

            toptask.time_stamp = dt.strftime("%H:%M")
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

    # Get MongoDB database using singleton connection
    database = MongoDBConnection.get_database()
    logger.info("MongoDB connection initialized...")

    toptasks_collection = database["toptasksurvey"]

    try:
        for index in range(TIMES_TO_LOOP):
            # Receive messages from queue
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL, MaxNumberOfMessages=1, WaitTimeSeconds=0
            )

            messages = response.get("Messages", [])

            if not messages:
                logger.info("No more messages in queue")
                break

            for message in messages:
                try:
                    # Get message body
                    message_body = message["Body"]
                    receipt_handle = message["ReceiptHandle"]

                    # Decode if base64 encoded
                    try:
                        decoded_string = base64.b64decode(message_body).decode("utf-8")
                    except Exception:
                        decoded_string = message_body

                    # Remove HTML tags
                    decoded_string = decoded_string.replace("<html><body><pre>", "")
                    decoded_string = decoded_string.replace("</pre></body></html>", "")

                    # HTML decode
                    decoded_string = unescape(decoded_string)

                    logger.info(f"Decoded string: {decoded_string}")

                    # Determine format: JSON (form) or delimited (email)
                    toptask = None

                    # Try parsing as JSON first (form submission)
                    try:
                        json_data = json.loads(decoded_string)
                        logger.info("Detected JSON format (form submission)")
                        toptask = parse_toptask_json(json_data)
                    except json.JSONDecodeError:
                        # Not JSON, try delimiter-separated format (email)
                        logger.info("Not JSON, trying delimiter format (email)")
                        top_task_data = decoded_string.split("~!~")
                        logger.info(f"Data size: {len(top_task_data)}")
                        toptask = parse_toptask_delimited(top_task_data)

                    if toptask:
                        # Insert into MongoDB
                        result = toptasks_collection.insert_one(toptask.to_dict())
                        logger.info(f"Records saved. TopTask ID: {result.inserted_id}")

                        times_looped += 1

                        # Delete message from queue
                        sqs.delete_message(
                            QueueUrl=QUEUE_URL, ReceiptHandle=receipt_handle
                        )
                        logger.info("The survey data has been dequeued.")
                    else:
                        logger.warning("Failed to parse message in either format")

                except PyMongoError as e:
                    logger.error(f"MongoDB error: {str(e)}", exc_info=True)
                except Exception as e:
                    logger.error(f"Error processing message: {str(e)}", exc_info=True)

    except Exception as e:
        logger.error(f"Error in process_queue_messages: {str(e)}", exc_info=True)
        raise
    finally:
        # Connection is managed by singleton, no need to close here
        pass

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
            "statusCode": 200,
            "body": json.dumps(
                {"messages_processed": times_looped, "elapsed_time_ms": elapsed_ms}
            ),
        }

    except Exception as e:
        logger.error(f"Error in TopTaskSurveyCommit: {str(e)}", exc_info=True)
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
