"""
MongoDB connection utilities for Lambda functions.
Provides singleton connection pooling for efficient database operations.
"""

import os
from typing import Optional
from pymongo import MongoClient
from pymongo.database import Database


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
            mongo_url = os.environ.get('MONGO_URL', '')
            mongo_port = int(os.environ.get('MONGO_PORT', '27017'))
            mongo_db = os.environ.get('MONGO_DB', 'pagesuccess')
            mongo_username = os.environ.get('MONGO_USERNAME', '')
            mongo_password = os.environ.get('MONGO_PASSWORD', '')
            environment = os.environ.get('ENVIRONMENT', 'production')
            
            if environment == 'staging':
                # Staging environment without authentication
                cls._client = MongoClient(mongo_url, mongo_port)
            else:
                # Production with TLS and authentication
                connection_string = (
                    f"mongodb://{mongo_username}:{mongo_password}@{mongo_url}:{mongo_port}/"
                    f"{mongo_db}?tls=true&tlsAllowInvalidCertificates=true&retryWrites=false"
                    f"&authSource={mongo_db}&authMechanism=SCRAM-SHA-1"
                )
                cls._client = MongoClient(connection_string)
        
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
        if cls._database is None or db_name:
            client = cls.get_client()
            db_name = db_name or os.environ.get('MONGO_DB', 'pagesuccess')
            cls._database = client[db_name]
        
        return cls._database
    
    @classmethod
    def close(cls):
        """Close MongoDB connection."""
        if cls._client:
            cls._client.close()
            cls._client = None
            cls._database = None
