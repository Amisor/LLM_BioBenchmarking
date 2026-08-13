#!/usr/bin/env python3

import sys
from biomni.agent import A1

prompt = sys.stdin.read()

agent = A1(
	path="./data",
	llm="claude-sonnet-4-20250514"
)

answer = agent.go(prompt)

print(answer)
