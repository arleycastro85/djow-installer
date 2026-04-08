#!/bin/bash

set -e

echo "🚀 DJOW OMEGA PATCH INICIANDO..."

BASE_DIR="$HOME/djow"

echo "📂 Verificando estrutura..."
if [ ! -d "$BASE_DIR" ]; then
  echo "❌ DJOW não encontrado em $BASE_DIR"
  exit 1
fi

echo "🧠 Aplicando patch no brain.py..."

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

def extract_json(text):
    try:
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match:
            return json.loads(match.group())
    except:
        pass
    return {"analysis": "erro parse", "action": "none"}

def decide(state, memory):
    context = "\n".join([
        m.get("content") or m.get("user", "")
        for m in memory[-5:]
    ])

    prompt = f"""
Você é DJOW OMEGA.

Responda APENAS em JSON válido.
NÃO escreva texto fora do JSON.
NÃO use markdown.
NÃO explique nada.

Formato obrigatório:
{{
  "analysis": "texto curto",
  "action": "comando linux ou none"
}}

Estado do sistema:
{state}

Histórico:
{context}
"""

    raw = run_llm(prompt)

    print("\n🧠 RAW:", raw)

    data = extract_json(raw)

    print("\n📦 JSON:", data)

    return data
EOF

echo "🧹 Resetando memória incompatível..."
rm -f $BASE_DIR/memory.json

echo "🔐 Garantindo permissões..."
chmod -R 755 $BASE_DIR

echo "✅ PATCH OMEGA APLICADO COM SUCESSO"

echo ""
echo "👉 Execute agora:"
echo "djow"
