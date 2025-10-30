I need to convert an Azure Functions C# project to AWS Lambda Python functions.

Context:

- Old repo (C# Azure Functions): [path to temp directory]
- New repo: [path to your repo]
- Conversion guide: agents.md in the root of new repo

Please read the agents.md file to understand the conversion requirements. Then:

1. Analyze the 5 C# functions in the old repo:

   - QueueProblem/run.csx
   - QueueProblemForm/run.csx
   - ProblemCommit/run.csx
   - QueueTopTask/run.csx
   - QueueTopTaskSurveyForm/run.csx
   - TopTaskSurveyCommit/run.csx

2. Convert each function to Python following the patterns in agents.md

3. Create the file structure as specified in agents.md:

   - src/queue_problem.py
   - src/queue_problem_form.py
   - src/problem_commit.py
   - src/queue_toptask.py
   - src/queue_toptask_survey.py
   - src/top_task_survey_commit.py
   - requirements.txt

4. Preserve all business logic from the C# code (especially device detection, email parsing, etc.)