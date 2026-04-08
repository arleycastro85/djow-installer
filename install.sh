#!/bin/bash

set -e

echo "🚀 DJOW OMEGA INSTALLER"

BASE_DIR="$HOME/djow"
mkdir -p $BASE_DIR

echo "📦 Instalando dependências..."
sudo apt update
sudo apt install -y python3 python3-pip curl

echo "🤖 Instalando Ollama..."
if ! command -v ollama &> /dev/null
then
  curl -fsSL https://ollama.com/install.sh | sh
fi

echo "📥 Baixando modelo otimizado..."
ollama pull mistral:7b-instruct-q4_K_M || true

echo "🧠 Criando estrutura OMEGA..."

mkdir -p $BASE_DIR/core
mkdir -p $BASE_DIR/agents
mkdir -p $BASE_DIR/runtime

############################################
# MEMORY
############################################
cat << 'EOF' > $BASE_DIR/core/memory.py
import json, os
from datetime import datetime

MEMORY_FILE = os.path.expanduser("~/djow/memory.json")

def load():
    if os.path.exists(MEMORY_FILE):
        with open(MEMORY_FILE, "r") as f:
            return json.load(f)
    return []

def save(mem):
    with open(MEMORY_FILE, "w") as f:
        json.dump(mem, f, indent=2)

def add(mem, role, content):
    mem.append({
        "time": str(datetime.now()),
        "role": role,
        "content": content
    })
    save(mem)
EOF

############################################
# EXECUTOR
############################################
cat << 'EOF' > $BASE_DIR/core/executor.py
import subprocess

SAFE = ["ls", "df", "free", "top", "nvidia-smi"]

def run(cmd):
    if not any(cmd.startswith(c) for c in SAFE):
        return "❌ comando bloqueado"

    try:
        return subprocess.check_output(cmd, shell=True, text=True)
    except Exception as e:
        return str(e)
EOF

############################################
# BRAIN
############################################
cat << 'EOF' > $BASE_DIR/core/brain.py
import subprocess

def ask(prompt):
    result = subprocess.run(
        ["ollama", "run", "mistral:7b-instruct-q4_K_M", prompt],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

def decide(state, memory):
    context = "\n".join([m["content"] for m in memory[-5:]])

    prompt = f"""
Você é DJOW OMEGA.

Analise o sistema e tome decisões.

Estado:
{state}

Histórico:
{context}

Responda JSON:
{{"analysis":"...", "action":"comando ou none"}}
"""
    return ask(prompt)
EOF

############################################
# SYSTEM AGENT
############################################
cat << 'EOF' > $BASE_DIR/agents/system_agent.py
import subprocess

def get():
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)'")
    mem = subprocess.getoutput("free -m")
    disk = subprocess.getoutput("df -h /")

    return f"""
CPU:
{cpu}

MEM:
{mem}

DISK:
{disk}
"""
EOF

############################################
# GPU AGENT
############################################
cat << 'EOF' > $BASE_DIR/agents/gpu_agent.py
import subprocess

def get():
    return subprocess.getoutput("nvidia-smi")
EOF

############################################
# LOOP
############################################
cat << 'EOF' > $BASE_DIR/runtime/loop.py
import json, time

from core.memory import load, add
from core.brain import decide
from core.executor import run

from agents.system_agent import get as sys_get
from agents.gpu_agent import get as gpu_get

def start():
    memory = load()

    while True:
        print("\n🔍 DJOW OMEGA MONITORANDO...\n")

        state = sys_get() + "\n" + gpu_get()

        raw = decide(state, memory)
        print("🧠 RAW:", raw)

        try:
            data = json.loads(raw)
        except:
            print("⚠️ erro JSON")
            time.sleep(10)
            continue

        add(memory, "analysis", data["analysis"])

        if data["action"] != "none":
            print("⚡ Executando:", data["action"])
            out = run(data["action"])
            print(out)
            add(memory, "action", out)

        time.sleep(20)
EOF

############################################
# MAIN
############################################
cat << 'EOF' > $BASE_DIR/djow.py
from runtime.loop import start

if __name__ == "__main__":
    start()
EOF

############################################
# GLOBAL COMMAND
############################################
sudo tee /usr/local/bin/djow > /dev/null << 'EOF'
#!/bin/bash
python3 ~/djow/djow.py
EOF

sudo chmod +x /usr/local/bin/djow

echo "✅ DJOW OMEGA INSTALADO COM SUCESSO"
echo "👉 Execute: djow"
