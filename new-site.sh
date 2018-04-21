echo 'Enter the site name: '
read name

mkdir -p /home/www/$name
touch /home/www/$name/bind.conf

chmod 0010 /home/www/$name

useradd -b /home/www -k /dev/null -m $name
groupadd $name
usermod -a -G $name $name

chown -R $name:$name /home/www/$name/

mkdir -p /home/www/$name/chroot/tmp
mkdir -p /home/www/$name/chroot/tmp/session
mkdir -p /home/www/$name/chroot/tmp/upload
mkdir -p /home/www/$name/chroot/tmp/misc
mkdir -p /home/www/$name/chroot/tmp/wsdl
mkdir -p /home/www/$name/chroot/log
mkdir -p /home/www/$name/chroot/data-$name

chown -R root:$name /home/www/$name/chroot/
chmod 0010 /home/www/$name/chroot/
chmod 0070 /home/www/$name/chroot/data-$name/
chmod 0030 /home/www/$name/chroot/log/
chmod 0010 /home/www/$name/chroot/tmp/
chmod 0030 /home/www/$name/chroot/tmp/*

cat > /etc/php/7.0/fpm/pool.d/$name.conf << EOF
[$name]
user = $name
group = $name

listen = /var/run/php/php7.0-fpm-$name.sock
listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

pm.status_path = /php7.0-fpm-status
ping.path = /php7.0-fpm-ping

access.log = /home/www/$name/chroot/log/php7.0-fpm.log
slowlog = /home/www/$name/chroot/log/php7.0-fpm-slow.log
request_slowlog_timeout = 15s
request_terminate_timeout = 20s

chroot = /home/www/$name/chroot/
chdir = /

; Flags & limits
php_flag[display_errors] = off
php_admin_flag[log_errors] = on
php_admin_value[error_log] = /home/www/$name/chroot/log/php7.0-fpm-error.log
php_admin_flag[expose_php] = off
php_admin_value[memory_limit] = 32M
php_admin_value[post_max_size] = 24M
php_admin_value[upload_max_filesize] = 20M
php_admin_value[cgi.fix_pathinfo] = 0

; Session
php_admin_value[session.entropy_length] = 1024
php_admin_value[session.cookie_httponly] = on
php_admin_value[session.hash_function] = sha512
php_admin_value[session.hash_bits_per_character] = 6
php_admin_value[session.gc_probability] = 1
php_admin_value[session.gc_divisor] = 1000
php_admin_value[session.gc_maxlifetime] = 1440

; Pathes
php_admin_value[include_path] = .
php_admin_value[open_basedir] = /data-$name/:/tmp/misc/:/tmp/upload/:/dev/urandom
php_admin_value[sys_temp-dir] = /tmp/misc
php_admin_value[upload_tmp_dir] = /tmp/upload
php_admin_value[session.save_path] = /tmp/session
php_admin_value[soap.wsdl_cache_dir] = /tmp/wsdl
php_admin_value[sendmail_path] = /usr/sbin/sendmail -f -i
php_admin_value[session.entropy_file] = /dev/urandom
php_admin_value[openssl.capath] = /etc/ssl/certs
EOF

service php7.0-fpm restart

cat > /etc/nginx/conf.d/$name.conf << EOF
server {
    listen 0.0.0.0:80;
    listen [::]:80;
    server_name $name www.$name;

    root /home/www/$name/chroot/data-$name;
    index index.html index.htm index.php;

    access_log /home/www/$name/chroot/log/nginx_access.log;
    error_log /home/www/$name/chroot/log/nginx_error.log error;

    location / {
        try_files \$uri \$uri/ =404;
        # WordPress
        # try_files $uri $uri/ /index.php?q=$uri&$args;
    }

    location ~ \.php$ {
        try_files  \$uri =404;
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/var/run/php/php7.0-fpm-$name.sock;
        fastcgi_param SCRIPT_FILENAME /data-$name\$fastcgi_script_name;
    }
}
EOF

echo '<?php phpinfo(); ?>' > /home/www/$name/chroot/data-$name/test.php

chown -R $name:$name /home/www/$name/chroot/data-$name/*
chmod -R 0640 /home/www/$name/chroot/data-$name/*
usermod -a -G $name www-data

chmod -R g+rX /home/www/$name/*
chmod -R u+rX /home/www/$name/*

service nginx restart

php-chroot-bind systemd update
systemctl restart php-chroots.target
php-chroot-bind status

certbot -d $name -d www.$name

mysql_name=`echo $name | tr '.' '_'`
echo $mysql_name
mysql_pw=`pwgen 10 1`
echo $mysql_pw
mysql -e "CREATE USER '$mysql_name'@'localhost' IDENTIFIED BY '$mysql_pw'"
mysql -e "CREATE DATABASE $mysql_name"
mysql -e "GRANT ALL ON $mysql_name.* TO '$mysql_name'@'localhost'"
mysql -e "FLUSH PRIVILEGES"
