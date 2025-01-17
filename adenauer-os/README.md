![Banderole](./banderole.png)

# Adenauer-OS


![os](os.png)

__Projekt des TikTok Archiver__



## Installation:


### System aktualisieren

Zuerst die Paketliste aktualisieren:

```bash
sudo apt-get update
```

_______________


### Erforderliche Pakete installieren

Installiere Nginx, Certbot und die notwendigen Abhängigkeiten:

```bash
sudo apt-get install nginx python3 certbot python3-certbot-nginx 
```



```bash
pip install flask gunicorn
```




________________________


### systemd-Servce einrichten

```bash
[Unit]
Description=Gunicorn instance to serve Flask application
After=network.target

[Service]
User=user
Group=www-data
WorkingDirectory=/home/user/tik-tok-serach-engine/collector
Environment="PATH=/home/user/tik-tok-search-engine/venv/bin"
ExecStart=/home/user/tik-tok-search-engine/venv/bin/gunicorn -w 3 -b 127.0.0.1:5000 app:app

[Install]
WantedBy=multi-user.target
```

_______________

### Basic NGINX-Config

```bash
server {
    server_name tiktok.domain.de;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    listen 80;
}

server {
    listen 80;
    server_name tiktok.domain.de;

    location / {
        return 404;
    }
}
```


```bash
sudo nano /etc/nginx/sites-available/tiktok.domain.de
```

```bash
sudo ln -s /etc/nginx/sites-available/tiktok.domain.de /etc/nginx/sites-enabled/
```

_______________


### SSL-Zertifikat mit Lets Encrypt..


```bash
sudo certbot --nginx -d tiktok.der-adenauer.de
```

Tests der automatischen Erneuerung der Zertifikate:

sudo certbot renew --dry-run

________________________

### Nginx-Konfiguration überprüfen:

```bash
sudo nginx -t
```


```bash
sudo systemctl reload nginx
```


![Banderole](./banderole.png)