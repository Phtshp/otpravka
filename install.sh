#!/bin/bash
set -e

# Перед запуском:
# GITHUB_TOKEN="твой_токен" bash install.sh

REPO_URL="https://github.com/roflsphtshp/otpravka"
INSTALL_DIR="$HOME/otprava"
BRANCH="main"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN не задан!"
    exit 1
fi

sudo dnf install -y python3 python3-pip git python3-requests >/dev/null 2>&1

# Клонируем или обновляем репозиторий
if [ ! -d "$INSTALL_DIR" ]; then
    git clone "$REPO_URL" "$INSTALL_DIR" >/dev/null 2>&1
else
    cd "$INSTALL_DIR" && git pull >/dev/null 2>&1
fi

mkdir -p ~/.config/otpravit
echo "$GITHUB_TOKEN" > ~/.config/otpravit/token
chmod 600 ~/.config/otpravit/token

sudo tee /usr/bin/otpravit >/dev/null <<'EOF'
#!/usr/bin/env python3
import os, sys, base64, requests

TOKEN_FILE = os.path.expanduser("~/.config/otpravit/token")
GITHUB_TOKEN = open(TOKEN_FILE).read().strip()
REPO = "roflsphtshp/otpravka"
BRANCH = "main"
API_URL = f"https://api.github.com/repos/{REPO}/contents"
HEADERS = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}

def upload_file(filepath):
    if os.path.isfile(filepath) and os.path.dirname(filepath) == "":
        path = os.path.basename(filepath)
    else:
        path = os.path.relpath(filepath, start=os.getcwd()).replace("\\","/")

    url = f"{API_URL}/{path}"
    with open(filepath, "rb") as f:
        content = base64.b64encode(f.read()).decode()

    # GET только для получения sha, не выходим при 404
    try:
        r = requests.get(url, headers=HEADERS)
        sha = r.json().get("sha") if r.status_code == 200 else None
    except:
        sha = None

    payload = {"message": f"update {path}" if sha else f"create {path}",
               "content": content,
               "branch": BRANCH}
    if sha:
        payload["sha"] = sha

    r2 = requests.put(url, json=payload, headers=HEADERS)
    if r2.status_code in [200,201]:
        print(f"[OK] {path} загружен")
    else:
        print(f"[ERROR] {path} не загружен: {r2.text}")

def upload(filepath):
    if os.path.isdir(filepath):
        for root, _, files in os.walk(filepath):
            for f in files:
                upload_file(os.path.join(root, f))
    else:
        upload_file(filepath)

def download_file(path):
    url = f"{API_URL}/{path}"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200: return
    content = base64.b64decode(r.json()["content"])
    if "/" in path: os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path,"wb") as f: f.write(content)
    print(f"[OK] {path} скачан")

def download_folder(folder_path):
    url = f"{API_URL}/{folder_path}"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200: return
    data = r.json()
    for item in data:
        if item["type"]=="dir":
            download_folder(item["path"])
        else:
            download_file(item["path"])

cmd = os.path.basename(sys.argv[0])
if len(sys.argv) < 2: sys.exit("Не указан файл или папка")
arg = sys.argv[1]

if cmd == "otpravit":
    upload(arg)
elif cmd == "skachat":
    r = requests.get(f"{API_URL}/{arg}", headers=HEADERS)
    if r.status_code != 200:
        print(f"[ERROR] {arg} не найден на GitHub")
        sys.exit()
    data = r.json()
    if isinstance(data, list):
        download_folder(arg)
    elif isinstance(data, dict):
        download_file(arg)
EOF

sudo chmod +x /usr/bin/otpravit
sudo ln -sf /usr/bin/otpravit /usr/bin/skachat
