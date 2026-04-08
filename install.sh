#!/bin/bash
set -e

echo "🚀 DJOW OMEGA — INSTALL CLEAN"

BASE="$HOME/djow"
rm -rf $BASE
mkdir -p $BASE/{core,runtime,system}

echo "📦 Dependências..."
sudo apt update -y
sudo apt install -y python3 python3-pip curl

echo "🤖 Ollama..."
if ! command -v ollama &> /dev/null; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

echo "📥 Modelo..."
ollama pull mistral:7b-instruct-q4_K_M || true

########################################
# PARSER (ROBUSTO)
########################################
cat << 'EOF' > $BASE/core/parser.py
import json, re

def parse(text):
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if not match:
        return {"analysis": "no json", "action": "none"}

    raw = match.group()

    # normalizações críticas
    raw = raw.replace("None", '"none"')
    raw = raw.replace(": none", ': "none"')
    raw = raw.replace(": None", ': "none"')

    try:
        return json.loads(raw)
    except:
        return {"analysis": "parse fail", "action": "none"}
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
- never use None
- no markdown
- no explanation

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
# LOOP
########################################
cat << 'EOF' > $BASE/runtime/loop.py
import time

from core.brain import decide
from core.parser import parse
from system.monitor import get

def start():
    while True:
        print("\n🔍 DJOW OMEGA\n")

        state = get()
        raw = decide(state)

        print("RAW:", raw)

        data = parse(raw)

        print("JSON:", data)

        time.sleep(10)
EOF

########################################
# ENTRYPOINT
########################################
cat << 'EOF' > $BASE/djow.py
from runtime.loop import start

if __name__ == "__main__":
    start()
EOF

########################################
# GLOBAL CMD
########################################
sudo tee /usr/local/bin/djow > /dev/null << 'EOF'
#!/bin/bash
python3 ~/djow/djow.py
EOF

sudo chmod +x /usr/local/bin/djow

echo "✅ DJOW OMEGA INSTALADO"
echo "👉 Execute: djow"
