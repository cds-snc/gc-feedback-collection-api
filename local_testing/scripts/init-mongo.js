// MongoDB initialization script for local development
// Creates the pagesuccess database with required collections

db = db.getSiblingDB('pagesuccess');

// Create collections
db.createCollection('problem');
db.createCollection('originalproblem');
db.createCollection('toptasksurvey');

// Create indexes for better query performance
db.problem.createIndex({ "problemDate": 1 });
db.problem.createIndex({ "url": 1 });
db.problem.createIndex({ "institution": 1 });
db.problem.createIndex({ "processed": 1 });

db.toptasksurvey.createIndex({ "dateTime": 1 });
db.toptasksurvey.createIndex({ "surveyReferrer": 1 });
db.toptasksurvey.createIndex({ "processed": 1 });

print('Database initialized successfully with collections: problem, originalproblem, toptasksurvey');
