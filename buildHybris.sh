## stop hybris #
#if [ "$(ps -afe | grep "/opt/hybris/bin/platform" | grep -v grep | awk '/java/{print $2}')" ]; then
#  ps -afe | grep "hybris/bin/platform" | grep -v grep | awk '/java/{print $2}'
#  kill ps -afe | grep "/opt/hybris/bin/platform" | grep -v grep | awk '/java/{print $2}'
#  echo "Stoping Hybris..."
#else
#  echo "Hybris os not running..."
#fi

# Change execute method in scripts
sed -i "s/exec .\//exec bash .\//g" /opt/hybris/bin/platform/tomcat/bin/catalina.sh
sed -i "s/COMMAND=\".\//COMMAND=\"bash .\//g" /opt/hybris/bin/platform/hybrisserver.sh

# stop hybris #
echo "Stopping hybris..."
sudo su hybris -c "cd /opt/hybris/bin/platform && bash hybrisserver.sh stop"

# clone hybris-5 repo to: /tmp/hybris/ #
BUCKET="s3://medic-animal-code-pipeline-artifacts"
BUCKET_PREFIX_HYBRIS="staging_medic_animal/Hybris"
HYBRIS=$(aws s3 ls $BUCKET/$BUCKET_PREFIX_HYBRIS --recursive | sort | tail -n 1 | awk '{print $4}')
aws s3 cp $BUCKET/$HYBRIS /tmp/latest_hybris.zip
cd /tmp || exit
unzip latest_hybris.zip && unzip hybris.zip -d /tmp/hybris/

# clone python-configurator repo to: /tmp/medicanimal-python-configurator/ #
BUCKET_PREFIX_PYTHON="staging_medic_animal/Python"
PYTHON=$(aws s3 ls $BUCKET/$BUCKET_PREFIX_PYTHON --recursive | sort | tail -n 1 | awk '{print $4}')
aws s3 cp $BUCKET/$PYTHON /tmp/latest_python.zip
cd /tmp || exit
unzip latest_python.zip && unzip python.zip -d /tmp/medicanimal-python-configurator/

# Remove zip files with github repos
cd /tmp || exit
rm -rf latest_hybris.zip latest_python.zip hybris.zip python.zip

# start python script
echo "Running python..."
cd /tmp/medicanimal-python-configurator/ || exit
python3 props_maker.py staging eu-west-2 eu-west-1

# remove folders #
echo "Deleting folders..."
rm -rf /opt/hybris/config
rm -rf /opt/hybris/bin/custom

# copy files from source #
echo "Copying files from github repo..."
cp -R /tmp/hybris/config /opt/hybris/config
cp -R /tmp/hybris/bin/custom /opt/hybris/bin/custom
cp -R /home/hybris/licence /opt/hybris/config/

# copy from codeDeploy generated catalina prop file
mkdir -p /opt/hybris/config/tomcat/conf
# from codeDeploy   <- memcahe URL
cp /tmp/medicanimal-python-configurator/catalina.properties /opt/hybris/config/tomcat/conf/catalina.properties

# copy local.properties.j2 to /opt/hybris/config/local.properties
echo "Copying local.properties..."
cp /tmp/medicanimal-python-configurator/local.properties /opt/hybris/config/local.properties

echo "Copying jgroups-tcp.xml..."
cp /tmp/medicanimal-python-configurator/jgroups-tcp.xml /opt/hybris/config/jgroups-tcp.xml

# sed to local.prop file
echo "Replace ip_instance with EC2_PRIVATE_IP var..."
EC2_PRIVATE_IP=$(ec2metadata --local-ipv4)
sed -i "s/ip_instance/$EC2_PRIVATE_IP/g" /opt/hybris/config/local.properties
cat /opt/hybris/config/local.properties | grep cluster.bro
echo "$EC2_PRIVATE_IP"

# chown hybris user
echo "Changing permissions to /opt/hybris..."
chown hybris:hybris -R /opt/hybris/temp
chown hybris:hybris -R /opt/hybris/bin
chown hybris:hybris -R /opt/hybris/config

# set envs
echo "Running setantenv.sh..."
sudo su hybris -c "cd /opt/hybris/bin/platform && . ./setantenv.sh"

# ant clean
echo "Ant clean..."
sudo su hybris -c "cd /opt/hybris/bin/platform && ant customize clean all"

# start hybris
echo "Starting hybris..."
sudo su hybris -c "cd /opt/hybris/bin/platform && bash hybrisserver.sh start"

# remove python configurator
echo "Removing github repos..."
rm -rf /tmp/medicanimal-python-configurator
rm -rf /tmp/hybris

#startListeners()
#{
#    http_code=$(curl -LI http://localhost:9001/warehouse/jms/startListeners -o /dev/null -w '%{http_code}\n' -s)
#    if [ ${http_code} -eq 200 ]; then
#        echo "http://localhost:9001/warehouse/jms/startListener : 200"
#    else
#        echo "http://localhost:9001/warehouse/jms/startListener : Repeating..."
#        sleep 10
#        startListeners
#    fi
#}
#
#startListeners
