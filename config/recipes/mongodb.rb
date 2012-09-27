set_default(:mongodb_password){ Capistrano::CLI.password_prompt "MongoDB root Password: " }
set_default(:mongoid_username) { application }
set_default(:mongoid_password) { Capistrano::CLI.password_prompt "Mongoid Password: " }
set_default(:mongoid_database) { "#{application}_production" }

namespace :mongodb do
  desc "Install the latest stable release of mongodb. And install root user"
  task :install, roles: :db, only: {primary: true} do
    run "#{sudo} apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10"
    run "echo \"deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen\" | #{sudo} tee -a /etc/apt/sources.list.d/10gen.list"
    run "#{sudo} apt-get -y update"
    run "#{sudo} apt-get -y install mongodb-10gen"
    run "mongo admin --eval \"db.getSiblingDB('admin').addUser('root', '#{mongodb_password}');\""
    run "#{sudo} rm -f  /etc/mongodb.conf"
    template "mongodb.conf.erb", "/tmp/mongodb_conf"
    run "#{sudo} mv /tmp/mongodb_conf /etc/mongodb.conf"
    restart
  end
  after "deploy:install", "mongodb:install"

  desc "Create a database for this application."
  task :create_database, roles: :db, only: {primary: true} do
    run "mongo -u root -p #{mongodb_password} admin --eval \"db.getSiblingDB('#{mongoid_database}').addUser('#{mongoid_username}', '#{mongoid_password}');\""
  end
  after "deploy:setup", "mongodb:create_database"

  desc "Generate the mongoid.yml configuration file."
  task :setup, roles: :app do
    run "mkdir -p #{shared_path}/config"
    template "mongoid.yml.erb", "#{shared_path}/config/mongoid.yml"
  end
  after "deploy:setup", "mongodb:setup"

  desc "Symlink the database.yml file into latest release"
  task :symlink, roles: :app do
    run "ln -nfs #{shared_path}/config/mongoid.yml #{release_path}/config/mongoid.yml"
  end
  after "deploy:finalize_update", "mongodb:symlink"
  
  %w[status start stop restart].each do |command|
    desc "#{command} mongodb"
    task command, roles: :web do
      run "#{sudo} #{command} mongodb"
    end
  end
end
