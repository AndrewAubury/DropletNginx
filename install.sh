#!/bin/bash
chmod +x ./install.config
. ./install.config
apt-get update -y
apt-get upgrade --yes
localedef -i en_US -f UTF-8 en_US.UTF-8
apt-get install ufw
ufw status
sed -i 's/IPV6=no/IPV6=yes/g' /etc/default/ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status
apt-get install jq nginx mariadb-server php-fpm php-mysql -y
rootpassword="`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`"
echo "Root MySQL Password: $rootpassword" > logins.txt

#echo "UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';"  >> mysqlinstall.sql
#echo "DELETE FROM mysql.user WHERE User='';"  >> mysqlinstall.sql
#echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"  >> mysqlinstall.sql
#echo "DROP DATABASE IF EXISTS test;"  >> mysqlinstall.sql
#echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"  >> mysqlinstall.sql
#echo "FLUSH PRIVILEGES;" >> mysqlinstall.sql

apt-get install snapd -y
source ~/.bashrc
snap install core; snap refresh core
source ~/.bashrc
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
snap set certbot trust-plugin-with-root=ok
snap install certbot-dns-cloudflare

mkdir -p ~/.secrets/certbot
echo "# Cloudflare API token used by Certbot" > ~/.secrets/certbot/cloudflare.ini
echo "dns_cloudflare_api_token = $cloudflaretoken" >> ~/.secrets/certbot/cloudflare.ini
chmod 600 -R ~/.secrets/certbot
certbot certonly --dns-cloudflare-propagation-seconds 30 --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini --noninteractive --agree-tos --register-unsafely-without-email -d "*.$rootdomain" -d "$rootdomain" -i nginx

# Set the Internal Field Separator (IFS) to a comma
IFS=','

# Convert the CSV string into an array
read -ra values_array <<< "$subdomains"

# Loop through the array
for value in "${values_array[@]}"; do
	echo "Current value: $value"
	mysqlname="site_$value"
	fulldomain="$value.$rootdomain"
	curpassword="`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`"
	echo "$mysqlname MySQL Password: $curpassword" >> logins.txt
	echo "CREATE DATABASE $mysqlname;" >> mysqlinstall.sql
	echo "GRANT ALL ON $mysqlname.* TO '$mysqlname'@'localhost' IDENTIFIED BY '$curpassword' WITH GRANT OPTION;" >> mysqlinstall.sql
	echo "FLUSH PRIVILEGES;" >> mysqlinstall.sql
	# You can perform any operation you want with $value here
	mkdir /var/www/$fulldomain
	mkdir /var/www/$fulldomain/html
	mkdir /var/www/$fulldomain/css
	mkdir /var/www/$fulldomain/js
	mkdir /var/www/$fulldomain/img
	touch /var/www/$fulldomain/css/styles.css
	touch /var/www/$fulldomain/js/scripts.js
	echo "<center><h1>$fulldomain</h1><h3>Headless install by AndrewAubury</h3><center>" > /var/www/$fulldomain/html/index.html

	
configBlock=$(cat <<EOL
server {
    listen 80;
    listen [::]:80;

    listen 443 ssl;
    listen [::]:443 ssl;

    ssl_certificate /etc/letsencrypt/live/$rootdomain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$rootdomain/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot    
    root /var/www/$fulldomain/html;
    index index.html index.php index.htm;

    server_name $fulldomain;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock; # /var/run/php/php8.2-fpm.sock
    }
    location ~* \.(js|jpg|jpeg|png|css)$ {
        root /var/www/dev.$fulldomain.online;
        try_files \$uri \$uri/ /img\$uri /html\$uri /css\$uri /js\$uri /theme\$uri =404;
    }
}
EOL
)

echo "$configBlock" > /etc/nginx/sites-available/$fulldomain.conf
ln -s /etc/nginx/sites-available/$fulldomain.conf /etc/nginx/sites-enabled/

done

chown -R $USER:$USER /var/www
chmod -R 755 /var/www
# Reset the IFS to its default value
IFS=$' \t\n'

mysql -sfu root < "mysqlinstall.sql"

myIP="`curl -s https://api.ipify.org`"

echo "Adding DNS Recods."

API_KEY="$cloudflaretoken"
# Get Zone ID for the specified domain
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$rootdomain" \
-H "Authorization: Bearer $API_KEY" \
-H "Content-Type: application/json" | jq -r '.result[0].id')

if [ -z "$ZONE_ID" ]; then
  echo "Failed to retrieve Zone ID for $DOMAIN. Check your domain or API key."
  exit 1
fi


# Cloudflare API endpoint for creating an A record
API_ENDPOINT="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"

for value in "${values_array[@]}"; do
# JSON payload for creating the A record
PAYLOAD='{
  "type": "A",
  "name": "'"$value"'",
  "content": "'"$myIP"'",
  "ttl": 600,
  "proxied": true
}'

# Make the API request to create the A record
RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
-H "Authorization: Bearer $API_KEY" \
-H "Content-Type: application/json" \
--data "$PAYLOAD")

# Check if the request was successful
if [[ $RESPONSE == *"success\":true"* ]]; then
  echo "A record added successfully for $value."
else
  	echo "Failed to add A record. Error: $RESPONSE"
fi
done
