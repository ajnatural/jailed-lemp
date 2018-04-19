echo 'Enter the site name: '
read name

php-chroot-bind unbind

rm -rf /home/www/$name
rm /etc/php/7.0/fpm/pool.d/$name.conf
rm /etc/nginx/conf.d/$name.conf

userdel $name
groupdel $name

service php7.0-fpm restart
service nginx restart

php-chroot-bind systemd update
systemctl restart php-chroots.target
php-chroot-bind status

mysql_name=`echo $name | tr '.' '_'`
echo $mysql_name
mysql -e "DROP DATABASE $mysql_name"
mysql -e "DROP USER '$mysql_name'@'localhost'"
mysql -e "FLUSH PRIVILEGES"

certbot delete
