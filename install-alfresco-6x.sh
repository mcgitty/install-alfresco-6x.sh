#!/bin/bash
(( ${#JAVA_HOME} == 0 )) && echo Error: missing JAVA_HOME environment variable. && exit
stuff=`ls`
if (( ${#stuff} != 0 )); then
  echo Current folder is not empty. Press Ctrl-C to cancel or ENTER to continue.
  read
fi
from=${0%/*} && (( $# > 0 )) && from="$1"
for f in apache_tomcat alfresco_content alfresco_search; do
  for found in $from/${f/_/-}-*.zip; do break; done
  [[ ! -f ${found} ]] && echo Error: cannot find $from/${f/_/-}-*.zip && exit
  echo Found $found
  eval ${f}="$found"
done
for ver in ${alfresco_content//-/ }; do [[ $ver == [0-9]* ]] && break; done
for jdk in `"$JAVA_HOME/bin/java" -version 2>&1`; do
  jdk=${jdk//\"} && [[ $jdk == [0-9]* ]] && break
done
if [[ $ver > "6.2" && $jdk < "11" ]]; then
  echo ACS 6.2 or higher requires JAVA_HOME set to JDK 11 or higher
  exit
fi
[ "$jdk" \< "1.9" ] && JDK8_OPTS="-XX:+UseConcMarkSweepGC -XX:+UseParNewGC"

mkdir -p modules/platform modules/share tmp
unzip -q $apache_tomcat -d tmp
mv tmp/* tomcat
unzip -q $alfresco_search -d tmp
mv tmp/* search-services
unzip -q $alfresco_content -d tmp
if [[ -d tmp/bin ]]; then # no parent folder in ACS zip
  mv tmp/* .
else
  cd tmp/*; mv * ../..; cd ../..; rmdir tmp/*
fi
mv tmp logs

chmod +x bin/*.sh tomcat/bin/*.sh
cd tomcat/conf
ln -s ../../web-server/conf/Catalina .
sed -i.bak -e 's|connectionTimeout=|URIEncoding="UTF-8" connectionTimeout=|' server.xml
sed -i.bak -e 's|shared.loader=|shared.loader=${catalina.base}/shared/classes|' catalina.properties
cd ..
rm -rf webapps
ln -s ../web-server/webapps .
ln -s ../web-server/shared .
cat > bin/setenv.sh <<-END
	JAVA_HOME="${JAVA_HOME}"
	JAVA_OPTS="-XX:+DisableExplicitGC -Djava.awt.headless=true -XX:ReservedCodeCacheSize=128m \$JAVA_OPTS"
	JAVA_OPTS="-Xms512M -Xmx8192M -Djgroups.bind_addr=127.0.0.1 \$JAVA_OPTS $JDK8_OPTS"
	export JAVA_HOME JAVA_OPTS
END
cd ..
cat > alfresco.sh <<-'END'
	#!/bin/bash

	cd `dirname $0`
	catalina=tomcat/bin/catalina.sh

	export LC_ALL="en_US.UTF-8"
	export JAVA_OPTS="-Dalfresco.home=$PWD"
	export CATALINA_PID=tomcat/temp/catalina.pid

	if [ -f $catalina ]; then
	  if [ "$*" == "stop" ]; then $catalina stop 20 -force; else $catalina "$@"; fi
	else
	  echo ERROR: $PWD/$catalina not found.
	fi
END
chmod +x alfresco.sh

for share in $from/alfresco*-share-*.zip; do break; done
if [[ -f ${share} ]]; then
  echo Found $share
  unzip -oj $share -d tomcat/webapps \*/share.war
  unzip -oj $share -d amps \*/alfresco-share-services.amp
  unzip -oj $share -d tomcat/conf/Catalina/localhost \*/share.xml
  unzip -oj $share -d tomcat/shared/classes/alfresco/web-extension/ \*/web-extension-samples/*
fi
if [[ `\ls amps` == *.* ]]; then
  bin/apply_amps.sh
  rm web-server/webapps/alfresco.war-*.bak
fi
if [[ -d alfresco-pdf-renderer ]]; then
  mv alfresco-pdf-renderer pdf-renderers
else
  mkdir pdf-renderers
fi
cd pdf-renderers; os=linux && [[ $OSTYPE == darwin* ]] && os=osx
if [[ ! -f alfresco-pdf-renderer-1.1-${os}.tgz ]]; then
  wget --no-check-certificate https://artifacts.alfresco.com/nexus/content/repositories/public/org/alfresco/alfresco-pdf-renderer/1.1/alfresco-pdf-renderer-1.1-${os}.tgz
fi
tar xzf alfresco-pdf-renderer-*-${os}.tgz
mv alfresco-pdf-renderer ../bin/
cd ../tomcat/lib
wget --no-check-certificate https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.48/mysql-connector-java-5.1.48.jar
cd ../..

sMode=none sParam='none"'
if [[ $ver > "7.1" ]]; then
  sMode=secret sParam='secret -Dalfresco.secureComms.secret=password"'
fi

# Disable https from solr to alfresco (NOT FOR PRODUCTION)
echo 'SOLR_OPTS="$SOLR_OPTS -Dalfresco.secureComms='$sParam >> search-services/solr.in.sh
echo JAVA_HOME=\"${JAVA_HOME}\" >> search-services/solr.in.sh
# First time Solr startup
search-services/solr/bin/solr start -a "-Dcreate.alfresco.defaults=alfresco,archive"

# Bare minimum properties
cat > web-server/shared/classes/alfresco-global.properties <<END
dir.root=$PWD/alf_data
dir.keystore=\${dir.root}/keystore

db.driver=org.gjt.mm.mysql.Driver
db.url=jdbc:mysql://localhost/alf620ce?useUnicode=yes&characterEncoding=UTF-8
db.username=alfresco
db.password=alfresco

jodconverter.officeHome=/Applications/LibreOffice.app/Contents
jodconverter.portNumbers=8101
jodconverter.enabled=false

alfresco.context=alfresco
alfresco.host=\${localname}
alfresco.port=8080
alfresco.protocol=http

share.context=share
share.host=\${localname}
share.port=8080
share.protocol=http

index.subsystem.name=solr6
solr.secureComms=$sMode
solr.port=8983
solr.host=localhost
solr.base.url=/solr
solr.sharedSecret=password

alfresco-pdf-renderer.exe=bin/alfresco-pdf-renderer
alfresco.rmi.services.host=0.0.0.0
messaging.broker.url=vm://localhost?broker.persistent=false
local.transform.service.enabled=false

smart.folders.enabled=true
smart.folders.model=alfresco/model/smartfolder-model.xml
smart.folders.model.labels=alfresco/messages/smartfolder-model
END

if [[ ! -d alf_data/keystore ]]; then
  mkdir -p alf_data/keystore
  cp -p keystore/metadata-keystore/* alf_data/keystore/
  cat >> web-server/shared/classes/alfresco-global.properties <<-'END'
	encryption.keystore.keyMetaData.location=${dir.keystore}/keystore-passwords.properties
	encryption.keystore.type=JCEKS
END
  cd web-server/webapps
  mkdir -p WEB-INF/lib
  wget --no-check-certificate -P WEB-INF/lib https://repo1.maven.org/maven2/org/apache/activemq/activemq-broker/5.15.9/activemq-broker-5.15.9.jar
  zip alfresco.war WEB-INF/lib/*
  rm -rf WEB-INF
fi
