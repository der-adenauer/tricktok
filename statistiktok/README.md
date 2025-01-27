### Shiny-App mit Systemd und Nginx bereitstellen

#### Neue Systemd-Service-Datei erstellen

1. **Service-Datei unter `/etc/systemd/system` erstellen**:

   ```shell
   sudo nano /etc/systemd/system/shiny-statistiktok.service
   ```

2. **Inhalt der Datei anpassen**:

   ```ini
   [Unit]
   Description=Shiny App - Statistiktok
   After=network.target

   [Service]
   User=charlie
   WorkingDirectory=/home/user/tricktok/statistiktok
   ExecStart=/usr/bin/env R_LIBS_USER=/home/user/R/libs /usr/bin/Rscript -e "shiny::runApp('.', port=12233, host='0.0.0.0')"
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

3. **Speichern und schließen** (STRG + X, gefolgt von Y und ENTER).

---

#### Systemctl-Befehle ausführen

1. **Daemon neu laden**:

   ```shell
   sudo systemctl daemon-reload
   ```

2. **Service starten**:

   ```shell
   sudo systemctl start shiny-statistiktok.service
   ```

3. **Automatischen Start aktivieren**:

   ```shell
   sudo systemctl enable shiny-statistiktok.service
   ```

4. **Status überprüfen**:

   ```shell
   sudo systemctl status shiny-statistiktok.service
   ```

---

#### Nginx-Konfiguration anpassen

1. **Nginx-Konfigurationsdatei öffnen**:

   ```shell
   sudo nano /etc/nginx/sites-available/default
   ```

2. **Neue `location`-Anweisung für die App hinzufügen**:

   ```nginx
   location /statistiktok/ {
       proxy_pass http://127.0.0.1:12233/;
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;

       proxy_connect_timeout 300;
       proxy_send_timeout 300;
       proxy_read_timeout 300;

       rewrite ^/statistiktok(/.*)$ $1 break;
   }
   ```

3. **Nginx-Konfiguration testen**:

   ```shell
   sudo nginx -t
   ```

4. **Nginx neu laden**:

   ```shell
   sudo systemctl reload nginx
   ```

---

#### Hinweise

1. **Port anpassen**:  
   Achte darauf, dass der Shiny-Service auf einem **eindeutigen Port** läuft. Hier wurde `9433` verwendet.  

2. **Zugänglichkeit überprüfen**:  
   Die neue App sollte über die URL `tricktok.afd-verbot.de/statistiktok` erreichbar sein.  

3. **Logs überprüfen** bei Problemen:  
   - Systemd-Logs:  
     ```shell
     sudo journalctl -u shiny-statistiktok.service
     ```
   - Nginx-Logs:  
     ```shell
     sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log
     ```  

