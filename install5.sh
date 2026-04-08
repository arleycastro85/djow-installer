#!/bin/bash

set -e

echo "🚀 DJOW CORE v2 INSTALL"

BASE="$HOME/djow"
mkdir -p $BASE/{core,actions,runtime,memory}

########################################
# MAIN
########################################
cat > $BASE/djow.py << 'EOF'
from runtime.loop import start

if __name__ == "__main__":
    start()
EOF

########################################
# BRAIN
########################################
cat > $BASE/core/brain.py << 'EOF'
import subprocess
import json

def run_llm(prompt):
    result = subprocess.run(
        ["ollama", "run", "mistral:7b-instruct-q4_K_M", prompt],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

def decide(state, memory, user):
    prompt = f"""
Você é um agente de sistema.

Responda SOMENTE JSON válido:

{{
"intent": "chat | system | execute",
"action": "none | cpu_check | disk_check | memory_check",
"response": "texto"
}}

Estado:
{state}

Usuário:
{user}
"""

    raw = run_llm(prompt)

    try:
        json_start = raw.find("{")
        json_end = raw.rfind("}") + 1
        clean = raw[json_start:json_end]
        return json.loads(clean)
    except:
        return {
            "intent": "chat",
            "action": "none",
            "response": raw
        }
EOF

########################################
# ACTIONS
########################################
cat > $BASE/actions/system.py << 'EOF'
import subprocess

def cpu():
    return subprocess.getoutput("top -bn1 | grep 'Cpu(s)'")

def memory():
    return subprocess.getoutput("free -h")

def disk():
    return subprocess.getoutput("df -h /")
EOF

########################################
# EXECUTOR
########################################
cat > $BASE/actions/executor.py << 'EOF'
from actions import system

def execute(action):
    if action == "cpu_check":
        return system.cpu()
    elif action == "memory_check":
        return system.memory()
    elif action == "disk_check":
        return system.disk()
    else:
        return None
EOF

########################################
# LOOP
########################################
cat > $BASE/runtime/loop.py << 'EOF'
import json
import os
from datetime import datetime
from core.brain import decide
from actions.executor import execute

MEMORY_FILE = os.path.expanduser("~/djow/memory/memory.json")

def load_memory():
    if os.path.exists(MEMORY_FILE):
        with open(MEMORY_FILE) as f:
            return json.load(f)
    return []

def save_memory(mem):
    with open(MEMORY_FILE, "w") as f:
        json.dump(mem, f, indent=2)

def get_state():
    return "Sistema ativo"

def start():
    memory = load_memory()

    while True:
        user = input("\n🧠 DJOW > ")

        if user in ["exit", "quit"]:
            break

        state = get_state()

        decision = decide(state, memory, user)

        print("\n📦 DECISION:", decision)

        action_output = execute(decision.get("action"))

        if action_output:
            print("\n⚡ RESULT:\n", action_output)

        print("\n🤖", decision.get("response"))

        memory.append({
            "time": str(datetime.now()),
            "user": user,
            "response": decision.get("response")
        })

        save_memory(memory)
EOF

########################################
# WRAPPER
########################################
sudo tee /usr/local/bin/djow > /dev/null << 'EOF'
#!/bin/bash
python3 ~/djow/djow.py
EOF

sudo chmod +x /usr/local/bin/djow

echo "✅ DJOW CORE v2 INSTALADO"
echo "👉 Execute: djow"
