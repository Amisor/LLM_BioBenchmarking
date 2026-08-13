import sys
import json

print("Python bridge started", file=sys.stderr, flush=True)

try:
    from biomni.agent import A1

    print("Biomni imported", file=sys.stderr, flush=True)

    agent = A1()

    print("Biomni initialized", file=sys.stderr, flush=True)

    print(
        json.dumps({"status": "ready"}),
        flush=True
    )

except Exception as e:

    print(
        f"ERROR: {type(e).__name__}: {e}",
        file=sys.stderr,
        flush=True
    )

    sys.exit(1)


for line in sys.stdin:

    if not line.strip():
        continue

    try:
        task = json.loads(line)

        response = agent.go(task["prompt"])

        print(
            json.dumps({
                "task_id": task["task_id"],
                "response": response,
                "error": None
            }),
            flush=True
        )

    except Exception as e:

        print(
            json.dumps({
                "task_id": task.get("task_id"),
                "response": None,
                "error": str(e)
            }),
            flush=True
        )
