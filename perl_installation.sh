#!/bin/bash

echo "This is an installation script for Perl Modules on Standard Lenny Image"

echo "All the Perl Modules required for VCL Management Node will be installed"

echo "Please enter the Path where you wish to extract Lenny Image (Prefereably extract in your /pvfs-surveyor space) ";
while read inputline
do
untarpath="$inputline"

if [ ! -d "$untarpath" ]; then
  echo "The Path entered does not exist. Please enter a valid Path"

else
        read -p "Confirm the Path [yes/no]: " RESPONSE
        if [ "$RESPONSE" = yes ] ; then
             break;
        else
           echo "Please enter the Path again !"
        fi
fi
done

echo "Untarring Lenny Image to the Specified Location. This will take a few Minutes. Lenny Image Size = 10GB";

cd $untarpath
pwd

#tar -zxvf /pvfs-surveyor/georgy/lenny/lenny.tar.gz

echo "Untarring Done"

cd ~/

echo "Creating the Kittyhawk Environment File in your Home Directory"

touch kh.env

cat <<EOF> kh.env

export BGPPROFILEDIR=/bgsys/argonne-utils/profiles
export BGPROFILE=kh
export PATH=\$PATH:\$BGPPROFILEDIR/\$BGPROFILE/opt/bin
export PATH=\$PATH:\$BGPPROFILEDIR/\$BGPROFILE/scripts
export PATH=\$PATH:\$BGPPROFILEDIR/\$BGPROFILE/bin
export PATH=\$PATH:\$BGPPROFILEDIR/\$BGPROFILE/khdev/bin
export PATH=\$PATH:\$BGPPROFILEDIR/\$BGPROFILE/khdev/kernels
export KH_Project="VCL-ON-BG_P"

EOF

cd ~/

echo "Starting BlueGene Job to customize Perl Installation"

# ---- KEY Generation ----

if [ -e .ssh/id_rsa -a -e .ssh/id_rsa.pub ]; then
 echo "SSH keys already exist and this will not be generated again"
else
 echo "SSH keys will be generated and saved in ~/.ssh directory"

/usr/bin/expect  << EOD
set timeout 5
spawn ssh-keygen -t rsa
expect "Enter file in which to save the key"
send "\r"
expect "Enter passphrase"
send "\r"
expect "Enter same passphrase again"
send "\r"
expect "pass"
EOD

fi

. kh.env

PWD='kh'

echo "Requesting 64 Nodes for a duration of 1 hour (Est 2min)"

/usr/bin/expect  << EOF > perllog
set timeout 120
spawn khqsub 60 64
expect "password:"
send "$PWD\r"

EOF

echo "Exporting the KittyHawk Control Server"

line=`grep pinging  perllog`
read -a arr <<<$line
var=${arr[1]}
echo $var
export khctlserver="$var"

PASS='kh'

echo "Starting the Base Node (Khdev Node)"
echo "Loading Lenny Image on the Base Node"

cd ~/


/usr/bin/expect  << EOD > perllog1
set timeout 45
spawn ./khdev.copy -p 1 -K "$(cat ~/.ssh/id_rsa.pub)" $untarpath/lenny.img
expect "password:"
send "$PASS\r"
expect "password:"
send "$PASS\r"
expect "password:"
EOD



echo "Customizing Provision and OS module files for the new username $USER";

echo "Collecting Details from the Base Node"

line=`grep inet base_eth0`

read -a arr <<<$line
var=${arr[1]}

declare -a Array=($(echo $var |cut -d':' --output-delimiter=" " -f1-))
external=${Array[1]}

echo "External IP Address of the Base Node: $external"
line=`grep inet base_eth1`

read -a arr <<<$line
var=${arr[1]}

declare -a Array=($(echo $var |cut -d':' --output-delimiter=" " -f1-))
internal=${Array[1]}

echo "Internal IP Address of the Base Node: $internal"


echo "Transfering perl modules and other VCL configuration files to the Base Node"

cp -r /pvfs-surveyor/georgy/vcl_files /pvfs-surveyor/georgy/vcl


echo "Please enter your username for the account"
read inputline
sed -i 's/georgy/'$inputline'/g' /pvfs-surveyor/georgy/vcl/lib/VCL/Module/Provisioning/bgp.pm


cp -r /pvfs-surveyor/georgy/vcl_config /pvfs-surveyor/georgy/vcl_config_files
echo "Please enter the root password set for the MySQL service"
read mysqlpass
sed -i 's/wrtPass=/wrtPass='$mysqlpass'/g' /pvfs-surveyor/georgy/vcl_config_files/vcld.conf

scp -r /pvfs-surveyor/georgy/perl root@$external:
scp -r /pvfs-surveyor/georgy/vcl root@$external:
scp -r /pvfs-surveyor/georgy/vcl_config_files root@$external:
scp -r ~/.ssh/id_rsa root@$external:/root/.ssh/
scp -r ~/.ssh/id_rsa.pub root@$external:/root/.ssh/

#scp -r /pvfs-surveyor/georgy/sources.list root@$external:/etc/apt


rm -rf /pvfs-surveyor/georgy/vcl
rm -rf /pvfs-surveyor/georgy/vcl_config_files

ssh -o StrictHostKeyChecking=no root@$external 'bash -s' <<EOF
cd perl
./script1
./script2
./script3
cd ~/

mv vcl /usr/local
mv vcl_config_files vcl

EOF

