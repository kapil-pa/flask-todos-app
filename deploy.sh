#!/bin/bash
set -e

APP_DIR="$HOME/todos-deploy"
APP_NAME="flask_todos"
PYTHON_PATH="/usr/bin/python3"
VENV_PATH="$APP_DIR/venv"

echo "---- Updating system ----"
sudo yum update -y

echo "---- Installing dependencies ----"
sudo yum install -y python3-pip nginx git

echo "---- Setting up virtual environment ----"
if [ ! -d "$VENV_PATH" ]; then
  $PYTHON_PATH -m venv $VENV_PATH
fi
source $VENV_PATH/bin/activate

echo "---- Installing Python packages ----"
pip install --upgrade pip
pip install -r $APP_DIR/requirements.txt

echo "---- Configuring Flask app ----"
# Copy .env if not exists
if [ ! -f "$APP_DIR/.env" ]; then
  echo "Missing .env file, creating default one..."
  cat > $APP_DIR/.env <<EOF
FLASK_ENV=production
SECRET_KEY=defaultkey
SQLALCHEMY_DATABASE_URI=sqlite:///todos.db
EOF
fi

echo "---- Creating systemd service ----"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Flask Todos App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$VENV_PATH/bin/flask run --host=0.0.0.0 --port=5000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "---- Enabling and starting service ----"
sudo systemctl daemon-reload
sudo systemctl enable ${APP_NAME}.service
sudo systemctl restart ${APP_NAME}.service

echo "---- Configuring Nginx ----"
sudo bash -c "cat > /etc/nginx/conf.d/${APP_NAME}.conf" <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo systemctl enable nginx
sudo systemctl restart nginx

echo "---- Deployment completed successfully ----"
