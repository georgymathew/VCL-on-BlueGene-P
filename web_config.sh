#!/bin/bash

#Collecting the Username for the ANL account

echo "Please enter your username for the account"
read username

sed -i 's/username/'$username'/g' ~/tun

echo "Please enter your port number of the MySQL service configured on Surveyor Login Node"
read portno


sed -i 's/port/'$portno'/g' ~/tun

echo "Please paste your private key. This will required for the front end configuration to login into the MySQL via ssh tunnel";

echo "Please enter a EOF limiter after you enter the key";

while read LINE
do
echo $LINE >> .scratch
if [ "$LINE" = "EOF" ];then
break
fi
done

sed -i '$d' .scratch

echo "Private key is saved"

cd ~/
chmod 600 .scratch

cp .scratch /var/www/html/vcl/.ht-inc/
cd /var/www/html/vcl/.ht-inc/
mv .scratch keyan
chmod 600 keyan
chown apache:apache keyan

cd ~/

echo "Please enter the password you configured for MySQL service on ANL Login Node"
read pass

#there is a problem in this line in the Image (the pass is still there in secrets.php - georgy pass)
sed -i 's/mysqlpass/'$pass'/g' /var/www/html/vcl/.ht-inc/secrets.php

#editing the username for the interaction scripts

sed -i 's/username/'$username'/g'/var/www/html/vcl/jb.php
sed -i 's/username/'$username'/g'/var/www/html/vcl/jp.php
sed -i 's/username/'$username'/g'/var/www/html/vcl/.ht-inc/t.sh
sed -i 's/username/'$username'/g'/var/www/html/vcl/.ht-inc/t1.sh
sed -i 's/username/'$username'/g'/var/www/html/vcl/.ht-inc/t2.sh
sed -i 's/username/'$username'/g'/var/www/html/vcl/.ht-inc/template.sh
sed -i 's/username/'$username'/g'/var/www/html/vcl/.ht-inc/hpc.sh

#editing the password for the interaction scripts
sed -i 's/mysqlpass/'$pass'/g'/var/www/html/vcl/jb.php
sed -i 's/mysqlpass/'$pass'/g'/var/www/html/vcl/jp.php
sed -i 's/mysqlpass/'$pass'/g'/var/www/html/vcl/.ht-inc/template.sh
sed -i 's/mysqlpass/'$pass'/g'/var/www/html/vcl/.ht-inc/hpc.sh

echo "Script Complete and all the necessary updates are made. You may now save the image".
echo "Please make the necessary edits in /var/www/html/vcl/.ht-inc/utils.php for daylight saving time problem"
