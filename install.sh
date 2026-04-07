#!/bin/bash

set -e

echo "🚀 DJOW INSTALLER STARTING..."

BASE_DIR="$HOME/djow"
mkdir -p $BASE_DIR

echo "📦 Instalando dependências..."

sudo apt update
sudo apt install -y python3 python3-pip curl

echo "🤖 Instalando Ollama (se necessário)..."

if ! command -v ollama &> /dev/null
then
  curl -fsSL https://ollama.com/install.sh | sh
fi

echo "📥 Baixando modelo..."

ollama pull mistral:7b-instruct-q4_K_M || true

echo "🧠 Criando estrutura DJOW..."

mkdir -p $BASE_DIR/core
mkdir -p $BASE_DIR/agents
mkdir -p $BASE_DIR/runtime

echo "📄 Criando arquivo principal..."

cat << 'EOF' > $BASE_DIR/djow.py
print("DJOW INSTALADO - PRONTO PARA PRÓXIMA FASE")
EOF

echo "⚙️ Criando comando global..."

sudo tee /usr/local/bin/djow > /dev/null << 'EOF'
#!/bin/bash
python3 ~/djow/djow.py
EOF

sudo chmod +x /usr/local/bin/djow

echo "✅ INSTALAÇÃO BASE FINALIZADA"
