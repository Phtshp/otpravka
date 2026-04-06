#!/bin/bash
set -e

# ===================
# Перед запуском укажи токен:
# GITHUB_TOKEN="твой_токен" bash install.sh
# ===================
REPO_URL="https://github.com/roflsphtshp/otpravka"
INSTALL_DIR="$HOME/otprava"
BRANCH="main"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN не задан!"
    exit 1
fi

# ===================
# Установка зависимостей
# ===================
sudo dnf install -y python3 python3-pip git python3-requests >/dev/null 2>&1

# ===================
# Клонирование репозитория
# ===================
if [ ! -d "$INSTALL_DIR" ]; then
    git clone "$REPO_URL" "$INSTALL_DIR" >/dev/null 2>&1
else
    cd "$INSTALL_DIR" && git pull >/dev/null 2>&1
fi

# ===================
# Сохраняем токен
# ===================
mkdir -p ~/.config/otpravit
echo "$GITHUB_TOKEN" > ~/.config/otpravit/token
chmod 600 ~/.config/otpravit/token

# ===================
# Создание CLI
# ===================
sudo tee /usr/bin/otpravit >/dev/null <<'EOF'
#!/usr/bin/env python3
import os, sys, base64, requests

TOKEN_FILE = os.path.expanduser("~/.config/otpravit/token")
GITHUB_TOKEN = open(TOKEN_FILE).read().strip()
REPO = "roflsphtshp/otpravka"
BRANCH = "main"
API_URL = f"https://api.github.com/repos/{REPO}/contents"
HEADERS = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}

def upload(filepath):
    if os.path.isdir(filepath):
        for root, _, files in os.walk(filepath):
            for f in files:
                upload(os.path.join(root, f))
        return
    if not os.path.exists(filepath): return

    with open(filepath,"rb") as file:
        content = base64.b64encode(file.read()).decode()

    # путь относительно текущей рабочей директории
    path = os.path.relpath(filepath, start=os.getcwd()).replace("\\","/")
    url = f"{API_URL}/{path}"

    r = requests.get(url, headers=HEADERS)
    sha = r.json().get("sha") if r.status_code==200 else None
    data = {"message": f"upload {path}", "content": content, "branch": BRANCH}
    if sha: data["sha"] = sha
    r2 = requests.put(url,json=data,headers=HEADERS)
    if r2.status_code not in [200,201]:
        print("Ошибка при загрузке:", r2.text)

def download(path):
    url = f"{API_URL}/{path}"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200: return
    content = base64.b64decode(r.json()["content"])
    if "/" in path: os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path,"wb") as f: f.write(content)

def download_folder(folder_path):
    url = f"{API_URL}/{folder_path}"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200: return
    data = r.json()
    for item in data:
        if item["type"]=="dir":
            download_folder(item["path"])
        else:
            download(item["path"])

cmd = os.path.basename(sys.argv[0])
if len(sys.argv) < 2: sys.exit()
arg = sys.argv[1]

r = requests.get(f"{API_URL}/{arg}", headers=HEADERS)
if r.status_code != 200: sys.exit()
data = r.json()

if cmd == "otpravit":
    upload(arg)
elif cmd == "skachat":
    if isinstance(data, list):
        download_folder(arg)
    elif isinstance(data, dict):
        download(arg)
EOF

sudo chmod +x /usr/bin/otpravit
sudo ln -sf /usr/bin/otpravit /usr/bin/skachat

# ===================
# Проверка команд
# ===================
command -v otpravit >/dev/null 2>&1 || echo "❌ otpravit не установлен"
command -v skachat >/dev/null 2>&1 || echo "❌ skachat не установлен"
