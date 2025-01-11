#!/bin/bash

# validate project name function
validate_project_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# prompt for the project name until a valid one is found
PROJECT_NAME=$1
while true; do
    if [ -d "$PROJECT_NAME" ]; then
        # invalid project name: existing directory
        echo "Directory '$PROJECT_NAME' already exists, please choose another project name."
        echo "Allowed characters: (letters, digits, '_' or '-'):"
        read PROJECT_NAME
    elif ! validate_project_name "$PROJECT_NAME"; then
        # invalid project name: disallowed characters
        echo "Enter a valid project name."
        echo "Allowed characters: (letters, digits, '_' or '-'):"
        read PROJECT_NAME
    else
        # valid project name
        break
    fi
done

# create project directory and navigate into it
mkdir $PROJECT_NAME && cd $PROJECT_NAME

# create virtualenv
python3 -m venv venv

# activate virtualenv
source venv/bin/activate

# update pip
pip3 install -U pip

# install django
pip3 install django

# create requirements file with installed django version
touch requirements.txt
echo "Django==$(python -m django --version)" >> requirements.txt

# create django project inside src folder
mkdir src
django-admin startproject app src
cd src

# init git repository
git init

# run database migrations
python3 manage.py migrate

# create superuser
# - username: admin
# - password: admin
# - email: admin@example.com
DJANGO_SUPERUSER_USERNAME=admin DJANGO_SUPERUSER_EMAIL=admin@example.com DJANGO_SUPERUSER_PASSWORD=admin python3 manage.py createsuperuser --noinput

# add static and media settings
cat <<EOF >> app/settings.py

STATIC_ROOT = BASE_DIR.parent / "public" / "static"
STATIC_URL = "static/"

MEDIA_ROOT = BASE_DIR.parent / "public" / "media"
MEDIA_URL = "media/"

EOF

# collect static files
python3 manage.py collectstatic --clear --noinput

# run local server in the background and store its PID
python3 manage.py runserver &
SERVER_PID=$!

# define a cleanup function
cleanup() {
    echo "Stopping the server..."
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
}

# trap SIGINT (Control + C) and call the cleanup function
trap cleanup SIGINT

# wait for the server to start
sleep 2

SERVER_URL="http://127.0.0.1:8000/"

# open the browser at localhost (cross-platform)
if command -v xdg-open > /dev/null; then
    # Linux
    xdg-open $SERVER_URL
elif command -v open > /dev/null; then
    # macOS
    open $SERVER_URL
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    # Windows (Cygwin, Git Bash, or native)
    start $SERVER_URL
else
    # fallback
    echo "Please open $SERVER_URL in your browser."
fi

# wait indefinitely (required to keep the script alive for trap to work)
wait
