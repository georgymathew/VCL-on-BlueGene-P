#!/bin/bash

echo "This is an installation script for Perl Modules on Standard Lenny Image"

echo "All the Perl Modules required for VCL Management Node will be installed"

echo "Please enter the Path where you wish to extract Lenny Image (Prefereably extract in your /pvfs-surveyor/$USER space) .Please do not put a trailing slash in the end of the path";
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

echo "Untarring Lenny Image to the Specified Location. This will take about 10 Minutes. Lenny Image Size = 10GB";

cd $untarpath
pwd

tar -zxvf /pvfs-surveyor/georgy/lenny.tar.gz

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

#Loading the Kittyhawk environment Variables
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


let count=0
declare -a ARRAY

while read LINE; do
ARRAY[$count]=$LINE
((count++))
done < log

qsubid=${ARRAY[2]}

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

cp -r /pvfs-surveyor/georgy/vcl_files /pvfs-surveyor/$USER/vcl


echo "Please enter your username for the account"
read inputline
sed -i 's/georgy/'$inputline'/g' /pvfs-surveyor/$USER/vcl/lib/VCL/Module/Provisioning/bgp.pm


cp -r /pvfs-surveyor/georgy/vcl_config /pvfs-surveyor/$USER/vcl_config_files
echo "Please enter the root password set for the MySQL service"
read mysqlpass

#this file does not have write persmissions so didnt work .. vcld.conf didnt not have the password
sed -i 's/wrtPass=/wrtPass='$mysqlpass'/g' /pvfs-surveyor/$USER/vcl_config_files/vcld.conf
cp /pvfs-surveyor/$USER/vcl_config_files/vcld.conf ~/vcld

scp -r /pvfs-surveyor/georgy/perl root@$external:
scp -r /pvfs-surveyor/$USER/vcl root@$external:
scp -r /pvfs-surveyor/$USER/vcl_config_files root@$external:
scp -r ~/.ssh/id_rsa root@$external:/root/.ssh/
scp -r ~/.ssh/id_rsa.pub root@$external:/root/.ssh/


rm -rf /pvfs-surveyor/$USER/vcl
rm -rf /pvfs-surveyor/$USER/vcl_config_files

ssh -o StrictHostKeyChecking=no root@$external 'bash -s' <<EOF
cd perl
./script1
./script2
./script3
cd ~/

mv vcl /usr/local
mv vcl_config_files vcl

EOF


echo "Editing the necessary API script"
cd ~/


echo "All the perl Modules are successfully installed"

echo "The node will be shutdown in 60 seconds"

sleep 60
ssh -o StrictHostKeyChecking=no root@$external 'bash -s' <<EOT
halt
EOT

read -r id<nbdid
echo nbd-server id is : $id
kill $id
qdel $qsubid

echo "BlueGene Job has been successfully deleted"


echo "The Lenny Image is now configured as the Management Node Image for VCL"
echo "Please enter a name to be assigned for the same. Please DO NOT put and .img extension";
read newname

cd $untarpath
mv lenny.img $newname.img

echo "The image is saved in the directory $untarpath"

val=/
img=lenny
newvar=$untarpath$val$newname
newva=$untarpath$val$img
echo $newvar

cd ~/
echo "Please enter your account username";
read usernam

cp /pvfs-surveyor/georgy/api/trigger.sh .
cp /pvfs-surveyor/georgy/api/provision.sh .
cp /pvfs-surveyor/georgy/api/provision2.sh .
cp /pvfs-surveyor/georgy/api/delete.sh .
cp /pvfs-surveyor/georgy/api/dreserv.sh .
cp /pvfs-surveyor/georgy/api/post.sh .

mv trigger.sh trigger_temp
mv provision.sh provision_temp
mv provision2.sh provision2_temp

sed -i 's/username/'$usernam'/g' trigger_temp
sed -i 's/username/'$usernam'/g' provision_temp
sed -i 's/username/'$usernam'/g' provision2_temp
sed -i 's/username/'$usernam'/g' delete.sh
sed -i 's/username/'$usernam'/g' dreserv.sh


# the port number in the patch did not take into account the port number

sed "150 a\spawn ./khdev.copy -p 1 -K \"\$(cat ~/.ssh/id_rsa.pub)\" $newvar.img" trigger_temp > trigger_temp2
sleep 5
sed "163 a\spawn ./khdev.copy -p \$net -K \"\$(cat ~/.ssh/id_rsa.pub)\" $newvar.img" trigger_temp2 > trigger.sh
chmod +x trigger.sh


sed "48 a\spawn ./khdev_template -n \$2 -K \"\$(cat ~/.ssh/id_rsa.pub)\" $newva.img" provision_temp > provision.sh
chmod +x provision.sh

sed "58 a\spawn ./khdev_bulk -z \$requestednodes -K \"\$(cat ~/.ssh/id_rsa.pub)\" $newva.img" provision2_temp > provision2.sh
chmod +x provision2.sh

rm trigger_temp
rm trigger_temp2
rm provision_temp
rm provision2_temp

echo "A new copy of Lenny image will be extracted at the same location to load on other nodes in the cluster"
cd ~/
cd $untarpath
pwd
tar -zxvf /pvfs-surveyor/georgy/lenny/lenny.tar.gz

#Appending the public key to the authorized_keys file
value=`cat ~/.ssh/id_rsa.pub`
echo "Public Key"
echo "$value"

read -p "Do you want to append the id_rsa.pub into the authorized_keys file (if you dont have it already appended please append noe.) [yes/no]: " RESPONSE
        if [ "$RESPONSE" = yes ] ; then
             echo $value >> ~/.ssh/authorized_keys;
        else
           echo "Nothing done !"
        fi
        
echo "Perl Installtion script complete"
