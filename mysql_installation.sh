#!/bin/bash
echo "----- This is a Scripted installtion of VCL MySQL Database -----";

cd /pvfs-surveyor/georgy/MYSQL

echo "----- Copying mysql.tar.gz into your Home Directory -----";
cp mysql.tar.gz ~/

cd ~/
echo "Untaring the Mysql Tar Ball";


tar -xzvf mysql.tar.gz > /dev/null
if [ "$?" -eq 0 ]; then
  echo "Contents of the Tar ball are extracted into the directory mysql which you can find in your Home Directory";
else
	echo "Extracting Contents of Tar Ball Failed";
fi

echo "Starting with the Installation Process";

cd /home/$USER/mysql/mysql-5.1.60

echo "Setting up Flags required for Compilation Process";

CFLAGS="-03" CXX=gcc CXXFLAGS="-03 -felide-constructors -fno-exceptions -fno-rtti" ;

echo "Compiling Files will take some time";

./configure --prefix=/home/$USER/MySQL/mysql \
                 --enable-assembler \
                  --enable-thread-safe-client \
                  --with-mysqld-user=$USER \
                 --with-unix-socket-path=/home/$USER/MySQL/mysql/tmp/mysql.sock \
                  --localstatedir=/home/$USER/MySQL/mysql/data \
                --with-named-curses-libs=/home/$USER/mysql/ncurses/lib/libncurses.a

echo "Configuring and installing the database";

make
make install

echo "Post Installation Steps !!";

echo "Ports that are already in use";

count=0;
while read LINE
do 
var1=$(echo $LINE | cut --delimiter='-' -f1)
echo $var1
port[$count]=$var1
count=`expr $count + 1`;
done < /pvfs-surveyor/georgy/MYSQL/used_ports

#echo ${port[2]}

echo Final Count : $count;
echo "Please enter the Port Number for MySQL service: ";
while read inputline
do
portno="$inputline"

if [[ " ${port[*]} " == *" $portno "* ]]; then
    echo "The port number entered already exists. Please enter a different one";
else
	read -p "Confirm the Port Number [yes/no]: " RESPONSE
	if [ "$RESPONSE" = yes ] ; then
	     break;
	else
	   echo "Please enter the port number again !"
	fi
fi
done

echo "The Port Number you have selected is $portno";

echo $portno-$USER >> /pvfs-surveyor/georgy/MYSQL/used_ports

cd ~/MySQL/mysql
mkdir log
mkdir etc

cd etc
touch my.cnf

cat <<EOF>/home/$USER/MySQL/mysql/etc/my.cnf
[mysqld]
user=$USER
basedir=/home/$USER/MySQL/mysql
datadir=/home/$USER/MySQL/mysql/data
port=$portno
socket=/home/$USER/MySQL/mysql/tmp/mysql.sock
bind-address=127.0.0.1

[mysqld_safe]
log-error=/home/$USER/MySQL/mysql/log/mysqld.log
pid-file=/home/$USER/MySQL/mysql/mysqld.pid

[client]
port=$portno
user=$USER
socket=/home/$USER/MySQL/mysql/tmp/mysql.sock

[mysqladmin]
user=root
port=$portno
socket=/home/$USER/MySQL/mysql/tmp/mysql.sock

[mysql]
port=$portno
socket=/home/$USER/MySQL/mysql/tmp/mysql.sock

[mysql_install_db]
user=$USER
port=$portno
basedir=/home/$USER/MySQL/mysql
datadir=/home/$USER/MySQL/mysql/data
socket=/home/$USER/MySQL/mysql/tmp/mysql.sock

EOF

#Change back to the Home Directory
cd ~/

#Adding the path in the PATH variable
echo  >> .bashrc
echo export PATH=/home/$USER/MySQL/mysql/bin:\$PATH >> .bashrc

#LOading the Bash variables PATH
. .bashrc

cd ~/
cp mysql/mysqld MySQL/
/home/$USER/MySQL/mysql/bin/mysql_install_db

#Starting the MySQL Service
/home/$USER/MySQL/mysql/bin/mysqld_safe --user=$USER & 

sleep 3

echo "Please enter the password for user 'root': "
while read inputline
do
pass="$inputline"
read -p "Confirm Password [yes/no]: " RESPONSE
if [ "$RESPONSE" = yes ] ; then
     break;
else
   echo "Please enter the password again !"
fi
done

echo "Password Set for user root for login to Database ";
/home/$USER/MySQL/mysql/bin/mysqladmin -u root password $pass


echo "<<<<-------- Now Script will run the mysql secure installation -------- >>>>";
#/home/$USER/MySQL/mysql/bin/mysql_secure_installation

/usr/bin/expect  << EOD
set timeout 30
spawn /home/$USER/MySQL/mysql/bin/mysql_secure_installation
expect "Enter current password for root (enter for none):"
send "$pass\r"
expect "Change the root password?"
send "n\r"
expect "Remove anonymous users?"
send "y\r"
expect "Disallow root login remotely?"
send "y\r"
expect "Remove test database"
send "y\r"
expect "Reload privilege"
send "y\r"
expect "pass"
EOD

/home/$USER/MySQL/mysql/bin/mysql -u root -p$pass << EOF
GRANT ALL PRIVILEGES ON *.* TO '$USER'@'localhost' WITH GRANT OPTION;
EOF


/home/$USER/MySQL/mysql/bin/mysql << EOF
CREATE DATABASE vcl;
EOF

#Loading the VCL Database
cd ~/
cd mysql
mysql vcl < final_clean.sql


echo "----- MySQL Database Installed Successfully -----";
