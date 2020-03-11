#!/bin/bash

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
mv /etc/apt/sources.list /etc/apt/sourses.list.backup
cat <<EOF > /etc/apt/sources.list
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF

sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql postgresql-server-dev-all -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s odoo" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 gdebi -y

echo -e "\n---- Install python packages/requirements ----"
sudo pip3 install -r https://github.com/odoo/odoo/raw/13.0/requirements.txt

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf
#--------------------------------------------------

echo -e "\n---- Install wkhtml----"
sudo apt install fontconfig libxrender1 xfonts-75dpi xfonts-base -y
apt --fix-broken install -y
dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb


#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
mkdir /var/lib/odoo
chmod -R 777 /var/lib/odoo
dpkg -i odoo-13.0+e.20191201.deb
apt install -f -y
#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
echo -e "\n---- Installing and setting up Nginx ----"
sudo apt install nginx -y
cat <<EOF > ~/odoo
server {
listen 80;
# set proper server name after domain set
server_name _;
# Add Headers for odoo proxy mode
proxy_set_header X-Forwarded-Host \$host;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_set_header X-Real-IP \$remote_addr;
add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
proxy_set_header X-Client-IP \$remote_addr;
proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;
#   odoo    log files
access_log  /var/log/nginx/access.log;
error_log       /var/log/nginx/error.log;
#   increase    proxy   buffer  size
proxy_buffers   16  64k;
proxy_buffer_size   128k;
proxy_read_timeout 900s;
proxy_connect_timeout 900s;
proxy_send_timeout 900s;
#   force   timeouts    if  the backend dies
proxy_next_upstream error   timeout invalid_header  http_500    http_502
http_503;
types {
text/less less;
text/scss scss;
}
#   enable  data    compression
gzip    on;
gzip_min_length 1100;
gzip_buffers    4   32k;
gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
gzip_vary   on;
client_header_buffer_size 4k;
large_client_header_buffers 4 64k;
client_max_body_size 0;
location / {
proxy_pass    http://127.0.0.1:8069;
# by default, do not forward anything
proxy_redirect off;
}
location /longpolling {
proxy_pass http://127.0.0.1:8072;
}
location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
expires 2d;
proxy_pass http://127.0.0.1:8069;
add_header Cache-Control "public, no-transform";
}
# cache some static data in memory for 60mins.
location ~ /[a-zA-Z0-9_-]*/static/ {
proxy_cache_valid 200 302 60m;
proxy_cache_valid 404      1m;
proxy_buffering    on;
expires 864000;
proxy_pass    http://127.0.0.1:8069;
}
}
EOF

sudo mv ~/odoo /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
sudo rm /etc/nginx/sites-enabled/default
sudo service nginx reload
sudo su root -c "printf 'proxy_mode = True\n' >> /etc/odoo/odoo.conf"
echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/odoo"

echo -e "* Starting Odoo Service"
sudo su root -c "/etc/init.d/odoo start"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: 8069"
echo "User service: odoo"
echo "User PostgreSQL: odoo"
echo "Code location: /usr/lib/python3/dist-packages/odoo"
echo "Addons folder: /usr/lib/python3/dist-packages/odoo/addons"
echo "Start Odoo service: sudo service odoo start"
echo "Stop Odoo service: sudo service odoo stop"
echo "Restart Odoo service: sudo service odoo restart"
echo "-----------------------------------------------------------"
