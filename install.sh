#!/bin/bash
set -e

# Установка python и requests
sudo dnf install -y python3 python3-requests >/dev/null 2>&1

# Проверка токена
if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN не задан!"
    exit 1
fi

# Сохраняем токен
mkdir -p ~/.config/otpravit
echo "$GITHUB_TOKEN" > ~/.config/otpravit/token
chmod 600 ~/.config/otpravit/token

# Клонируем репозиторий локально
git clone https://github.com/roflsphtshp/otpravka.git ~/.otprava || (cd ~/.otprava && git pull)

# Создаём скрипт otpravit
sudo tee /usr/bin/otpravit >/dev/null <<'EOF'
#!/usr/bin/env python3
import os, sys, shutil, subprocess

HOME = os.path.expanduser("~")
REPO_DIR = os.path.join(HOME, ".otprava")
TOKEN_FILE = os.path.join(HOME, ".config/otpravit/token")

if not os.path.exists(TOKEN_FILE):
    print("Токен не найден в ~/.config/otpravit/token")
    sys.exit(1)

if not os.path.exists(REPO_DIR):
    print("Локальная копия репозитория отсутствует. Пожалуйста, заново выполните install.sh")
    sys.exit(1)

def git_cmd(args):
    result = subprocess.run(args, cwd=REPO_DIR)
    if result.returncode != 0:
        print(f"Ошибка выполнения команды: {' '.join(args)}")
        sys.exit(1)

cmd = os.path.basename(sys.argv[0])
if len(sys.argv) < 2:
    print("Не указан файл или папка")
    sys.exit(1)
arg = sys.argv[1]

if cmd == "otpravit":
    dest = os.path.join(REPO_DIR, arg)
    if os.path.isdir(arg):
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.copytree(arg, dest)
    else:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(arg, dest)
    git_cmd(["git", "add", "."])
    git_cmd(["git", "commit", "-m", f"update {arg}"])
    git_cmd(["git", "push", f"https://{open(TOKEN_FILE).read().strip()}@github.com/roflsphtshp/otpravka.git", "main"])
    print(f"[OK] {arg} отправлен")
elif cmd == "skachat":
    src = os.path.join(REPO_DIR, arg)
    if os.path.isdir(src):
        shutil.copytree(src, arg, dirs_exist_ok=True)
    else:
        shutil.copy2(src, arg)
    print(f"[OK] {arg} скачан")
elif cmd == "prosmotret":
    path = os.path.join(REPO_DIR, arg) if arg else REPO_DIR
    for root, dirs, files in os.walk(path):
        for d in dirs:
            print(f"dir  {os.path.relpath(os.path.join(root,d), REPO_DIR)}")
        for f in files:
            print(f"file {os.path.relpath(os.path.join(root,f), REPO_DIR)}")
EOF

sudo chmod +x /usr/bin/otpravit
sudo ln -sf /usr/bin/otpravit /usr/bin/skachat
sudo ln -sf /usr/bin/otpravit /usr/bin/prosmotret

echo "Установка завершена. Команды otpravit, skachat и prosmotret доступны."
