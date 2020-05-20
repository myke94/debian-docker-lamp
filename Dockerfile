FROM debian:buster-slim

COPY sed/php_replace.sed /
COPY sed/replace_opcache.sed /
COPY conf/xdebug.ini /

RUN apt-get update
RUN apt-get install -y wget nano sudo curl unzip git systemd gnupg2 ca-certificates lsb-release apt-transport-https ufw

# Install PHP
ENV PHP_VERSION 7.3

RUN apt-get install -y php libapache2-mod-php php-cli php-fpm php-json php-pdo php-mysql php-zip php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-common php-dom php-simplexml php-ssh2 php-xmlreader php-exif  php-ftp php-iconv php-imagick php-posix php-sockets php-tokenizer php-imap php-bz2 php-intl php-gmp php-gettext
RUN sed -i.back -f php_replace.sed /etc/php/$PHP_VERSION/apache2/php.ini
RUN sed -i.back -f replace_opcache.sed /etc/php/$PHP_VERSION/apache2/conf.d/10-opcache.ini
RUN cat xdebug.ini >> /etc/php/$PHP_VERSION/apache2/conf.d/15-xdebug.ini

# Install mariadb
RUN apt-get install -y mariadb-server mariadb-client

# alternative to　"mysql_secure_installation"
RUN service mysql start && \
    mysqladmin -u root password "docker" && \
    mysql -u root -pdocker -e "DELETE FROM mysql.user WHERE User='';" && \
    mysql -u root -pdocker -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');" && \
    mysql -u root -pdocker -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" && \
    mysql -u root -pdocker -e "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY 'docker';" && \
    mysql -u root -pdocker -e "FLUSH PRIVILEGES;"

RUN sed -i 's/password = /password = docker/' /etc/mysql/debian.cnf
RUN sed -i 's/bind-address/#bind-address/' /etc/mysql/mariadb.conf.d/50-server.cnf

# Install openssl pour https : mod SSL
RUN apt-get install -y openssl
RUN a2enmod ssl
RUN a2ensite default-ssl

# Install Apache
RUN apt-get install -y apache2 apache2-doc libapache2-mod-php apache2-utils
RUN a2enmod rewrite
RUN a2enmod deflate
RUN a2enmod headers

# Install adminer
ENV ADMINER_VERSION 4.7.7
RUN wget https://github.com/vrana/adminer/releases/download/v$ADMINER_VERSION/adminer-$ADMINER_VERSION.php
RUN mkdir /usr/share/adminer
RUN mv adminer-$ADMINER_VERSION.php /usr/share/adminer/index.php
RUN chown -R www-data:www-data /usr/share/adminer
RUN ln -s /usr/share/adminer /var/www/html/adminer
COPY style/adminer.css /usr/share/adminer/adminer.css

# Install SSH
RUN apt-get install -y openssh-server
RUN ufw allow ssh
RUN echo 'root:docker' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
RUN ssh-keygen -A
RUN mkdir -p /run/sshd

# Install supervisor
RUN apt-get install -y supervisor
COPY conf/supervisord.conf /etc/supervisor/supervisord.conf
COPY conf/apache.conf /etc/supervisor/conf.d/apache.conf
COPY conf/mariadb.conf /etc/supervisor/conf.d/mariadb.conf
COPY conf/ssh.conf /etc/supervisor/conf.d/ssh.conf

# Install NodeJS/npm, composer, Less
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php
RUN php composer-setup.php --install-dir=/usr/local/bin --filename=composer
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g less

# file cleaning
RUN rm php_replace.sed
RUN rm replace_opcache.sed
RUN rm xdebug.ini
RUN rm composer-setup.php

# 22 = ssh; 25 = smtp; 80=http; 443=https; 3306=mysql; 9000=xdebug; 9001=supervisor
EXPOSE 22 25 80 443 3306 9000 9001
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
