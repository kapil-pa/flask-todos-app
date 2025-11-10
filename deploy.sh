#!/bin/bash
set -e

APP_NAME="flask_todos"
APP_DIR="/home/ubuntu/todos-deploy"
VENV_DIR="$APP_DIR/venv"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
NGINX_CONF="/etc/nginx/conf.d/${APP_NAME}.conf"
PYTHON_BIN="/usr/bin/python3"

echo "-----------------------------"
echo "🚀 Starting Flask deployment"
echo "-----------------------------"

# --- 1️⃣ System update & dependencies ---
echo "📦 Updating system and installing dependencies..."
sudo yum update -y
sudo yum install -y python3 python3-pip nginx git

# --- 2️⃣ Create virtual environment ---
if [ ! -d "$VENV_DIR" ]; then
  echo "🐍 Creating virtual environment..."
  $PYTHON_BIN -m venv $VENV_DIR
fi

# Activate venv
source $VENV_DIR/bin/activate

# --- 3️⃣ Install app dependencies ---
echo "📚 Installing Python dependencies..."
pip install --upgrade pip
pip install -r $APP_DIR/requirements.txt

# --- 4️⃣ Flask environment setup ---
if [ ! -f "$APP_DIR/.env" ]; then
  echo "⚙️ Creating default .env file..."
  cat > $APP_DIR/.env <<EOF
FLASK_ENV=production
SECRET_KEY=default_secret_key
SQLALCHEMY_DATABASE_URI=sqlite:///todos.db
EOF
fi

# --- 5️⃣ Create or update systemd service ---
echo "🛠️ Setting up systemd service..."

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Flask Todos App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$VENV_DIR/bin/flask run --host=0.0.0.0 --port=5000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# --- 6️⃣ Start and enable service ---
echo "🚦 Restarting Flask service..."
sudo systemctl daemon-reload
sudo systemctl enable ${APP_NAME}.service
sudo systemctl restart ${APP_NAME}.service

# --- 7️⃣ Configure Nginx as reverse proxy ---
echo "🌐 Configuring Nginx..."

sudo bash -c "cat > $NGINX_CONF" <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo systemctl enable nginx
sudo systemctl restart nginx

# --- 8️⃣ Firewall (optional) ---
if command -v firewall-cmd >/dev/null 2>&1; then
  echo "🔒 Configuring firewall..."
  sudo firewall-cmd --permanent --add-service=http || true
  sudo firewall-cmd --reload || true
fi

echo "✅ Deployment successful!"
echo "Your Flask app is now live at: http://$(curl -s ifconfig.me)"

