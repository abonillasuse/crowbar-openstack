name "trove"
maintainer "SUSE Linux GmbH"
maintainer_email "crowbar@dell.com"
license "Apache 2.0"
description "Cookbook for OpenStack Trove"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version "0.1.0"
recipe "trove::default", "Troves"

depends "database"
depends "utils"
depends "nova"
depends "keystone"
depends "swift"
depends "cinder"
depends "rabbitmq"

supports "suse"
