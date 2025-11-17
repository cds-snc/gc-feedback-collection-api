"""
MongoDB connection utilities for Lambda functions.
Provides singleton connection pooling for efficient database operations.
Fetches credentials securely from SSM Parameter Store.
"""

import os
import boto3
from typing import Optional
from urllib.parse import quote_plus
from pymongo import MongoClient
from pymongo.database import Database


def get_mongo_credentials():
    """
    Fetch MongoDB credentials securely.
    In production: fetch from SSM Parameter Store
    In local: read from environment variables

    Returns:
        tuple: (username, password)
    """
    environment = os.environ.get("ENVIRONMENT", "production")

    if environment == "local":
        username = os.environ.get("MONGO_USERNAME", "")
        password = os.environ.get("MONGO_PASSWORD", "")
    else:
        # Get SSM parameter ARNs from environment
        username_param = os.environ.get("MONGO_USERNAME_PARAM", "")
        password_param = os.environ.get("MONGO_PASSWORD_PARAM", "")

        # Extract parameter name from ARN if needed
        if username_param.startswith("arn:"):
            username_param = "/" + username_param.split("parameter/")[-1]
        if password_param.startswith("arn:"):
            password_param = "/" + password_param.split("parameter/")[-1]

        # Fetch from SSM
        ssm = boto3.client("ssm")
        try:
            username_response = ssm.get_parameter(
                Name=username_param, WithDecryption=True
            )
            username = username_response["Parameter"]["Value"]

            password_response = ssm.get_parameter(
                Name=password_param, WithDecryption=True
            )
            password = password_response["Parameter"]["Value"]
        except Exception as e:
            raise Exception(f"Failed to fetch credentials from SSM: {str(e)}")

    return username, password


class MongoDBConnection:
    """
    Singleton MongoDB connection manager for Lambda functions.
    Maintains connection across Lambda warm starts.
    """

    _client: Optional[MongoClient] = None
    _database: Optional[Database] = None

    @classmethod
    def get_client(cls) -> MongoClient:
        """
        Get or create MongoDB client instance.

        Returns:
            MongoClient instance
        """
        if cls._client is None:
            mongo_url = os.environ.get("MONGO_URL", "")
            mongo_port = int(os.environ.get("MONGO_PORT", "27017"))
            mongo_db = os.environ.get("MONGO_DB", "pagesuccess")
            environment = os.environ.get("ENVIRONMENT", "production")

            # Fetch credentials securely
            mongo_username, mongo_password = get_mongo_credentials()

            # URL-encode credentials to handle special characters
            encoded_username = quote_plus(mongo_username) if mongo_username else ""
            encoded_password = quote_plus(mongo_password) if mongo_password else ""

            try:
                if environment == "local":
                    # Local development - no TLS
                    if encoded_username and encoded_password:
                        connection_string = (
                            f"mongodb://{encoded_username}:{encoded_password}@{mongo_url}:{mongo_port}/"
                            f"{mongo_db}?authSource=admin"
                        )
                        cls._client = MongoClient(connection_string)
                    else:
                        # No authentication
                        cls._client = MongoClient(mongo_url, mongo_port)
                else:
                    # Staging/Production with TLS and authentication
                    connection_string = (
                        f"mongodb://{encoded_username}:{encoded_password}@{mongo_url}:{mongo_port}/"
                        f"{mongo_db}?tls=true&retryWrites=false&authSource=admin"
                    )
                    cls._client = MongoClient(connection_string)
            except Exception as e:
                raise Exception(f"Failed to connect to MongoDB: {str(e)}")

        return cls._client

    @classmethod
    def get_database(cls, db_name: Optional[str] = None) -> Database:
        """
        Get database instance.

        Args:
            db_name: Optional database name override

        Returns:
            Database instance
        """
        try:
            if cls._database is None or db_name:
                client = cls.get_client()
                db_name = db_name or os.environ.get("MONGO_DB", "pagesuccess")
                cls._database = client[db_name]

            return cls._database
        except Exception as e:
            raise Exception(f"Failed to get database instance: {str(e)}")

    @classmethod
    def close(cls):
        """Close MongoDB connection."""
        if cls._client:
            cls._client.close()
            cls._client = None
            cls._database = None
