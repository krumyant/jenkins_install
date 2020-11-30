#!/bin/bash

function INSTALL_PRE_PACKAGES() {
  LIST_OF_PACKAGES=("$@")
  for PACKAGE in "${LIST_OF_PACKAGES[@]}"; do
    if ! rpm -qa | grep -qw "$PACKAGE"; then
      yum -y install "$PACKAGE"
    else
      echo "$PACKAGE is already installed"
      pass
    fi
  done
}


function JENKINS_INSTALL() {
  if ! rpm -qa | grep -qw "jenkins"; then
    wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
    yum checkcache
    yum -y install jenkins
  else
    echo "Jenkins is already installed"
    pass
  fi
}


function CONFIG_DEFAULT_USER() {
  CONFIG_FILE="/var/lib/jenkins/init.groovy.d/basic-security.groovy"
  mkdir -p "/var/lib/jenkins/init.groovy.d/"
  touch "/var/lib/jenkins/init.groovy.d/basic-security.groovy"
  USERNAME=$1
  PASSWORD=$2
  sed -i 's/JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true"/JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"/g' \
  /etc/sysconfig/jenkins
cat <<- EOF >"$CONFIG_FILE"
import java.util.logging.Level
import java.util.logging.Logger
import hudson.security.*
import jenkins.model.*

def instance = Jenkins.getInstance()
def logger = Logger.getLogger(Jenkins.class.getName())

logger.log(Level.INFO, "Ensuring that local user $USERNAME is created.")

if (!instance.isUseSecurity()) {
    logger.log(Level.INFO, "Creating local admin user $USERNAME")

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)

    def hudsonRealm = new HudsonPrivateSecurityRealm(false)
    hudsonRealm.createAccount("$USERNAME", "$PASSWORD")

    instance.setSecurityRealm(hudsonRealm)
    instance.setAuthorizationStrategy(strategy)
    instance.save()
}
EOF
  systemctl start jenkins
  systemctl enable jenkins
}


if [ "$1" == "" ]; then
  echo "You have not provided USERNAME; please re-run the script with arguments script.bash USERNAME PASSWORD"
  exit 1
elif [ "$2" == "" ]; then
  echo "You have not provided PASSWORD; please re-run the script with arguments script.bash USERNAME PASSWORD"
  exit 1
else
  LIST_OF_PACKAGES=("java-1.8.0-openjdk-devel")
  INSTALL_PRE_PACKAGES "${LIST_OF_PACKAGES[@]}"
  JENKINS_INSTALL
  CONFIG_DEFAULT_USER "$1" "$2"
fi
