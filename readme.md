# Headless Installation Script

This is a Bash script for headless installation of a web server stack with Nginx, MySQL (MariaDB), and PHP. It also automates the setup of SSL certificates using Certbot and Cloudflare DNS. Additionally, the script creates and configures virtual hosts for multiple subdomains.

## Features

- Automated installation of essential server components.
- Automatic SSL certificate generation and renewal using Certbot.
- Securely configure the firewall (UFW) with sensible defaults.
- Create MySQL databases and users for subdomains.
- Auto-generate strong passwords for MySQL users.
- Automatic DNS record creation with Cloudflare API.

## Prerequisites

Before running the script, make sure to set the following variables in the `install.config` file:

- `cloudflaretoken`: Your Cloudflare API token.
- `rootdomain`: Your root domain (e.g., example.com).
- `subdomains`: Comma-separated list of subdomains to be configured.

## Usage

1. Make the script executable:

   ```bash
   chmod +x ./install.sh
   ```

## Customization

You can customize the script to fit your specific needs. For example, you can modify the Nginx server block configuration in the script to match your site's requirements.
