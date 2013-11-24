# the following installation process was taken from gitlab.org. If installation fails please check gitlab.org's official documentation for installing gitlab
# the following shellscript will automate gitlab installation you just need to enter the variable values before running the script and please run the script as root
# written by Lawrence Santos

gitlab_ip=172.16.0.185
git_user=lawrence
git_email=lawrence@aiming-inc.com.ph
database_pass=aiming
hostname=ubuntu

apt-get update -y
apt-get upgrade -y
apt-get install sudo -y
apt-get install -y vim
update-alternatives --set editor /usr/bin/vim.basic
apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate
apt-get install -y python
apt-get install -y git-core
debconf-set-selections <<< "postfix postfix/mailname string $hostname"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install -y postfix


mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz | tar xz
cd ruby-2.0.0-p353
./configure --disable-install-rdoc
make
sudo make install
sudo gem install bundler --no-ri --no-rdoc

sudo adduser --disabled-login --gecos 'GitLab' git
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
sudo -u git -H cp config.yml.example config.yml
sudo -u git -H sed -i 's/localhost/'${gitlab_ip}'/g' config.yml
sudo -u git -H sed -i '12s/false/true/g' config.yml
sudo -u git -H ./bin/install

echo "mysql-server-5.5 mysql-server/root_password password $database_pass" | debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $database_pass" | debconf-set-selections
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev
mysql -u root -p$database_pass -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$database_pass';"
mysql -u root -p$database_pass -e "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -u root -p$database_pass -e "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO 'gitlab'@'localhost';"

cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd /home/git/gitlab
sudo -u git -H git checkout 6-2-stable
cd /home/git/gitlab
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX  log/
sudo chmod -R u+rwX  tmp/
sudo -u git -H mkdir /home/git/gitlab-satellites
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
sudo chmod -R u+rwX  tmp/pids/
sudo chmod -R u+rwX  tmp/sockets/
sudo -u git -H mkdir public/uploads
sudo chmod -R u+rwX  public/uploads
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb
sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb
sudo -u git -H git config --global user.name "$git_user"
sudo -u git -H git config --global user.email "$git_email"
sudo -u git -H git config --global core.autocrlf input
sudo -u git cp config/database.yml.mysql config/database.yml
sudo -u git -H sed -i 's/root/gitlab/g' config/database.yml
sudo -u git -H sed -i 's/secure\ password/'${database_pass}'/g' config/database.yml

cd /home/git/gitlab
sudo -u git -H bundle install --deployment --without development test postgres aws
export force=yes
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production
sudo cp lib/support/init.d/gitlab /etc/init.d/gitlab
sudo chmod +x /etc/init.d/gitlab
sudo update-rc.d gitlab defaults 21
sudo cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
sudo service gitlab start
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
sudo apt-get install -y nginx
sudo cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
sudo service nginx restart
service gitlab restart


echo "You can now log in to your local Gitlab Server"
echo "Just type this in your http://$gitlab_ip"
echo "Username: admin@local.host"
echo "Initial Password: 5iveL!fe"
