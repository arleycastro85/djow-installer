#!/bin/bash
set -e

echo "🚀 DJOW GOD++ INSTALL"

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
        return {"analysis": "no json", "action": "none"}

    raw = match.group()
    raw = raw.replace("None", '"none"')
    raw = raw.replace(": none", ': "none"')

    try:
        return json.loads(raw)
    except:
        return {"analysis": "parse fail", "action": "none"}
EOF

########################################
# EXECUTOR (SEGURANÇA)
########################################
cat << 'EOF' > $BASE/core/executor.py
import subprocess

SAFE = ["ls", "df", "free", "uptime", "nvidia-smi"]

def run(cmd):
    if not any(cmd.startswith(c) for c in SAFE):
        return f"BLOCKED: {cmd}"

    try:
        return subprocess.getoutput(cmd)
    except Exception as e:
        return str(e)
EOF

########################################
# BRAIN
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
{{"analysis":"text","action":"command or none"}}

Rules:
- use only "none"
- no explanation
- no markdown

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
# LOOP GOD++
########################################
cat << 'EOF' > $BASE/runtime/loop.py
import time

from core.brain import decide
from core.parser import parse
from core.executor import run
from system.monitor import get

def start():
    while True:
        print("\n🔍 DJOW GOD++\n")

        state = get()
        raw = decide(state)

        print("RAW:", raw)

        data = parse(raw)

        print("JSON:", data)

        action = data.get("action", "none")

        if action != "none":
            print("\n⚡ EXECUTANDO:", action)
            output = run(action)
            print(output)

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

echo "✅ DJOW GOD++ INSTALADO"
