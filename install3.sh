#!/bin/bash
set -e

echo "🚀 DJOW OMEGA FINAL"

BASE="$HOME/djow"
rm -rf $BASE
mkdir -p $BASE/{core,runtime,system}

sudo apt update -y
sudo apt install -y python3 curl

if ! command -v ollama &> /dev/null; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

ollama pull mistral:7b-instruct-q4_K_M || true

########################################
# PARSER
########################################
cat << 'EOF' > $BASE/core/parser.py
import json, re

def parse(text):
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if not match:
        return {"analysis": "no json", "action": "none", "risk": "high"}

    raw = match.group()
    raw = raw.replace("None", '"none"')
    raw = raw.replace(": none", ': "none"')

    try:
        data = json.loads(raw)
        return {
            "analysis": data.get("analysis",""),
            "action": data.get("action","none"),
            "risk": data.get("risk","high")
        }
    except:
        return {"analysis": "parse fail", "action": "none", "risk": "high"}
EOF

########################################
# EXECUTOR INTELIGENTE
########################################
cat << 'EOF' > $BASE/core/executor.py
import subprocess

def run(cmd):
    try:
        return subprocess.getoutput(cmd)
    except Exception as e:
        return str(e)
EOF

########################################
# POLICY (CONTROLE)
########################################
cat << 'EOF' > $BASE/core/policy.py
def allow(action, risk):
    if action == "none":
        return False

    if risk == "low":
        return True

    if risk == "medium":
        return False

    if risk == "high":
        return False

    return False
EOF

########################################
# BRAIN (DECISÃO REAL)
########################################
cat << 'EOF' > $BASE/core/brain.py
import subprocess

def ask(prompt):
    result = subprocess.run(
        ["ollama", "run", "mistral:7b-instruct-q4_K_M", prompt],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

def decide(state):
    prompt = f"""
Return ONLY JSON.

Format:
{{
 "analysis": "short text",
 "action": "linux command or none",
 "risk": "low|medium|high"
}}

Rules:
- use only "none"
- no explanation
- no markdown
- classify risk correctly

System:
{state}
"""
    return ask(prompt)
EOF

########################################
# SYSTEM
########################################
cat << 'EOF' > $BASE/system/monitor.py
import subprocess

def get():
    cpu = subprocess.getoutput("top -bn1 | head -5")
    mem = subprocess.getoutput("free -h")
    disk = subprocess.getoutput("df -h /")
    return f"{cpu}\n{mem}\n{disk}"
EOF

########################################
# LOOP FINAL
########################################
cat << 'EOF' > $BASE/runtime/loop.py
import time

from core.brain import decide
from core.parser import parse
from core.executor import run
from core.policy import allow
from system.monitor import get

def start():
    while True:
        print("\n🧠 DJOW OMEGA FINAL\n")

        state = get()
        raw = decide(state)

        print("RAW:", raw)

        data = parse(raw)

        print("JSON:", data)

        action = data["action"]
        risk = data["risk"]

        if allow(action, risk):
            print(f"\n⚡ EXECUTANDO ({risk}):", action)
            print(run(action))
        else:
            print(f"\n🔒 BLOQUEADO ({risk}):", action)

        time.sleep(10)
EOF

########################################
# ENTRY
########################################
cat << 'EOF' > $BASE/djow.py
from runtime.loop import start

if __name__ == "__main__":
    start()
EOF

########################################
# CMD
########################################
sudo tee /usr/local/bin/djow > /dev/null << 'EOF'
#!/bin/bash
python3 ~/djow/djow.py
EOF

sudo chmod +x /usr/local/bin/djow

echo "✅ DJOW OMEGA FINAL INSTALADO"
