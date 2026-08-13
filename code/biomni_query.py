#!/usr/bin/env python3

import sys
import json
from biomni.agent import A1

# Initialize Biomni
agent = A1()

print(json.dumps({"status": "ready"}), flush = True)

# Read through benchmark tasks
for line in sys.stdin:
	if not line.strip():
		continue
	try:
		task = json.loads(line)
		response = agent.go(task["prompt")
		result = {
			"task_id": task["task_id"],
			"response": response,
			"error": None
		}
	except Exception as e:
		result = {
			"task_id": task["task_id"],
			"response": None,
			"error": str(e)
		}

	print(json.dumps(result), flush=True)
