#!/bin/bash
set -e

echo "🚀 DJOW ADVANCED AGENT INSTALL"

BASE="$HOME/djow"
rm -rf $BASE
mkdir -p $BASE/{core,tools,runtime,interface}

sudo apt update -y
sudo apt install -y python3 python3-pip curl

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
        return {"intent":"chat","action":"none","risk":"low"}

    raw = match.group()
    raw = raw.replace("None", '"none"')
    raw = raw.replace(": none", ': "none"')

    try:
        return json.loads(raw)
    except:
        return {"intent":"chat","action":"none","risk":"low"}
EOF

########################################
# POLICY
########################################
cat << 'EOF' > $BASE/core/policy.py
def decide(action, risk):
    if action == "none":
        return "ignore"

    if risk == "low":
        return "execute"

    if risk == "medium":
        return "suggest"

    return "block"
EOF

########################################
# LLM ENGINE
########################################
cat << 'EOF' > $BASE/core/llm.py
import subprocess

FAST_MODEL = "mistral:7b-instruct-q4_K_M"
SMART_MODEL = "mistral:7b-instruct-q4_K_M"

def run(model, prompt):
    result = subprocess.run(
        ["ollama", "run", model, prompt],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()
EOF

########################################
# TOOLS - SYSTEM
########################################
cat << 'EOF' > $BASE/tools/system.py
import subprocess

def run(cmd):
    return subprocess.getoutput(cmd)
EOF

########################################
# TOOLS - MONITOR
########################################
cat << 'EOF' > $BASE/tools/monitor.py
import subprocess

def get():
    cpu = subprocess.getoutput("top -bn1 | head -5")
    mem = subprocess.getoutput("free -h")
    disk = subprocess.getoutput("df -h /")
    gpu = subprocess.getoutput("nvidia-smi")
    return f"{cpu}\n{mem}\n{disk}\n{gpu}"
EOF

########################################
# TOOLS - SERVICES
########################################
cat << 'EOF' > $BASE/tools/services.py
import subprocess

def list_services():
    return subprocess.getoutput("systemctl list-units --type=service --state=running")

def restart(name):
    return subprocess.getoutput(f"sudo systemctl restart {name}")

def docker_ps():
    return subprocess.getoutput("docker ps")
EOF

########################################
# ORCHESTRATOR (CÉREBRO)
########################################
cat << 'EOF' > $BASE/core/orchestrator.py
from core.llm import run, FAST_MODEL, SMART_MODEL
from core.parser import parse

def decide(user, state):

    prompt = f"""
Return JSON only.

{{
 "intent":"chat|command|analysis",
 "action":"command or none",
 "risk":"low|medium|high"
}}

User:
{user}

System:
{state}
"""

    raw = run(FAST_MODEL, prompt)

    data = parse(raw)

    if data.get("intent") == "analysis":
        raw = run(SMART_MODEL, prompt)
        data = parse(raw)

    return data
EOF

########################################
# LOOP AUTÔNOMO
########################################
cat << 'EOF' > $BASE/runtime/agent.py
import time
from tools.monitor import get
from core.orchestrator import decide
from core.policy import decide as policy
from tools.system import run

def start():
    while True:
        state = get()
        data = decide("auto monitor", state)

        action = data.get("action","none")
        risk = data.get("risk","low")

        decision = policy(action, risk)

        if decision == "execute":
            print(f"\n⚡ AUTO EXEC:", action)
            print(run(action))

        time.sleep(15)
EOF

########################################
# CLI (INTERAÇÃO)
########################################
cat << 'EOF' > $BASE/interface/cli.py
from tools.monitor import get
from core.orchestrator import decide
from core.policy import decide as policy
from tools.system import run

def start():
    while True:
        user = input("\n🧠 DJOW > ")

        state = get()
        data = decide(user, state)

        action = data.get("action","none")
        risk = data.get("risk","low")

        decision = policy(action, risk)

        print("\nJSON:", data)

        if decision == "execute":
            print("\n⚡ EXEC:", action)
            print(run(action))
        elif decision == "suggest":
            print("\n💡 SUGESTÃO:", action)
        elif decision == "block":
            print("\n🔒 BLOQUEADO:", action)
EOF

########################################
# MAIN
########################################
cat << 'EOF' > $BASE/djow.py
import threading
from runtime.agent import start as auto
from interface.cli import start as cli

if __name__ == "__main__":
    threading.Thread(target=auto, daemon=True).start()
    cli()
EOF

########################################
# CMD GLOBAL
########################################
sudo tee /usr/local/bin/djow > /dev/null << 'EOF'
#!/bin/bash
python3 ~/djow/djow.py
EOF

sudo chmod +x /usr/local/bin/djow

echo "✅ DJOW ADVANCED AGENT INSTALADO"
echo "👉 Execute: djow"
