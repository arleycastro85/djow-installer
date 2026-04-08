#!/bin/bash
set -e

echo "🚀 DJOW OMEGA PATCH v2..."

BASE_DIR="$HOME/djow"

cat << 'EOF' > $BASE_DIR/core/brain.py
import subprocess
import json
import re

def run_llm(prompt):
    result = subprocess.run(
        ["ollama", "run", "mistral:7b-instruct-q4_K_M", prompt],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

def clean_json(text):
    # pega apenas o bloco JSON
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if not match:
        return {"analysis": "no json", "action": "none"}

    raw = match.group()

    # normalizações críticas
    raw = raw.replace("None", '"none"')
    raw = raw.replace("none", '"none"')

    try:
        return json.loads(raw)
    except:
        return {"analysis": "parse fail", "action": "none"}

def decide(state, memory):
    context = "\n".join([
        m.get("content") or m.get("user", "")
        for m in memory[-5:]
    ])

    prompt = f"""
Return ONLY valid JSON.

Format:
{{
 "analysis": "short text",
 "action": "linux command or none"
}}

Rules:
- never use None
- use only "none"
- no markdown
- no explanation

System:
{state}

History:
{context}
"""

    raw = run_llm(prompt)

    print("\nRAW:", raw)

    data = clean_json(raw)

    print("\nJSON:", data)

    return data
EOF

rm -f $BASE_DIR/memory.json

echo "✅ PATCH v2 OK"
