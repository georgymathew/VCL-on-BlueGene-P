#!/bin/bash
echo "Please enter the password you configured for MySQL service on ANL Login Node"
read username

echo "Please enter the password you configured for MySQL service on ANL Login Node"
read pass

#editing the username for the interaction scripts

sed -i 's/username/'$username'/g' /var/www/html/vcl/jb.php
sed -i 's/username/'$username'/g' /var/www/html/vcl/jp.php
sed -i 's/username/'$username'/g' /var/www/html/vcl/.ht-inc/t.sh
sed -i 's/username/'$username'/g' /var/www/html/vcl/.ht-inc/t1.sh
sed -i 's/username/'$username'/g' /var/www/html/vcl/.ht-inc/t2.sh
sed -i 's/username/'$username'/g' /var/www/html/vcl/.ht-inc/template.sh
sed -i 's/username/'$username'/g' /var/www/html/vcl/.ht-inc/hpc.sh

#editing the password for the interaction scripts
#not needed as the user goes as a passwordless access
sed -i 's/mysqlpass/'$pass'/g' /var/www/html/vcl/jb.php
sed -i 's/mysqlpass/'$pass'/g' /var/www/html/vcl/jp.php
sed -i 's/mysqlpass/'$pass'/g' /var/www/html/vcl/.ht-inc/template.sh
sed -i 's/mysqlpass/'$pass'/g' /var/www/html/vcl/.ht-inc/hpc.sh

echo "Script Completed"
