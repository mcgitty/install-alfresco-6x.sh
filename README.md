# A script to install Alfresco Community 6.0
## Motivation
Alfresco 6.0 switching to container deployment is a good thing, but Docker has [efficiency issues](https://github.com/moby/hyperkit/issues/231) on Mac. What's wrong with a well configured stand-alone Alfresco Community 6.0? Nothing!

## Download Three Files
This Bash script automates the installation of Alfresco Community 6.x. It looks for 3 downloaded files in the same folder of the script or a folder specified as the script's first parameter.

- [apache_tomcat-\*.zip](https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.37/bin/apache-tomcat-9.0.37.zip)
- [alfresco-content-\*.zip](https://artifacts.alfresco.com/nexus/content/repositories/public/org/alfresco/alfresco-content-services-community-distribution/6.2.0-ga/alfresco-content-services-community-distribution-6.2.0-ga.zip)
- [alfresco-search-\*.zip](https://artifacts.alfresco.com/nexus/content/repositories/public/org/alfresco/alfresco-search-services/1.4.0/alfresco-search-services-1.4.0.zip)

The above links are for Tomcat 9.0.37, ACS 6.2.0-ga, Search Services 1.4.0. Here are links for other versions:

- [alfresco-content-services-community-distribution-6.0.7-ga.zip](https://artifacts.alfresco.com/nexus/content/repositories/public/org/alfresco/alfresco-content-services-community-distribution/6.0.7-ga/alfresco-content-services-community-distribution-6.0.7-ga.zip)
- [alfresco-content-services-community-distribution-6.1.2-ga.zip](https://artifacts.alfresco.com/nexus/content/repositories/public/org/alfresco/alfresco-content-services-community-distribution/6.1.2-ga/alfresco-content-services-community-distribution-6.1.2-ga.zip)
- [alfresco-search-services-1.3.0.zip](https://artifacts.alfresco.com/nexus/content/repositories/public/org/alfresco/alfresco-search-services/1.3.0/alfresco-search-services-1.3.0.zip)
- [apache-tomcat-8.5.37.zip](https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.37/bin/apache-tomcat-8.5.37.zip)

## Run The Install Script
Create an empty folder into which a stand-alone Alfresco Community will be installed. Be sure to set the environment variable `JAVA_HOME`. Then run the installation script, assuming everything else is in the parent folder:

    mkdir 6.2.0-ga
    cd 6.2.0-ga
    ../install-alfresco-6x.sh

The script will install all three archives, create or modify configuration files and startup scripts, download MySQL JDBC driver and the missing PDF renderer for Mac, start Solr6. It also applies the Share module for `alfresco.war`, which will ask you to press a few keys in between.

## Create Your MySQL Schema
The script creates file `tomcat/shared/classes/alfresco-global.properties` with these MySQL database settings:

- Schema name: `alf620ce`
- User name: `alfresco`
- Password: `alfresco`

Here are the MySQL commands to create the schema:

    $ mysql -u root
    create schema alf620ce default character set utf8;
    grant all on alf620ce.* to 'alfresco'@'localhost' identified by 'alfresco' with grant option;

## Start and Stop Alfresco

    ./alfresco.sh start
    ./alfresco.sh jpda start # Start with debug
    ./alfresco.sh stop

## Start and Stop Solr 6
The install script already starts Solr 6 for you. Subsequent start and stop commands are:

    search-services/solr/bin/solr start
    search-services/solr/bin/solr stop

## Host Environments
This install script works in Mac OSX and Ubuntu. It should also work in other flavors of Linux, but it has not been tested in Cygwin or MinGW on Windows.


.
