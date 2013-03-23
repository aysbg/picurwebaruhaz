require "rvm/capistrano"
require "bundler/capistrano"
load 'deploy/assets'

set :rvm_ruby_string, 'ruby-1.9.3-p392'
set :rvm_type, :user

server "198.211.117.84", :web, :app, :db, primary: true

set :application, "picurwebaruhaz"
set :user, "gwuix2"
set :group, 'www-data'
set :rails_env, 'production'


set :scm, "git"
set :repository,  "git://github.com/gwuix2/picurwebaruhaz.git"
set :branch, "master"
set :deploy_to, "/home/#{user}/#{application}"


default_run_options[:pty] = true 

after "deploy:restart", "deploy:cleanup"

 namespace :deploy do
   task :start do ; end
   task :stop do ; end
   task :restart, :roles => :app, :except => { :no_release => true } do
     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
   end
 end


default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after "deploy", "deploy:cleanup" # keep only the last 5 releases


namespace :foreman do
  desc "Export the Procfile to Bluepill's .pill script"
  task :export, :roles => :app do
    run "cd #{current_path} && bundle exec foreman export bluepill /gwuix2/#{application}/shared/config"
    sudo "bluepill load /gwuix2/#{application}/shared/config/#{application}.pill"
  end

  desc "Start the application services"
  task :start, :roles => :app do
    sudo "bluepill #{application} start"
  end

  desc "Stop the application services"
  task :stop, :roles => :app do
    sudo "bluepill #{application} stop"
  end

  desc "Restart the application services"
  task :restart, :roles => :app do
    sudo "bluepill #{application} restart"
  end
end

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end
  

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  
  after "deploy:setup", "deploy:setup_config"

  
  task :create_symlinks do
    run "ln -nfs #{shared_path}/db/production.sqlite3 #{release_path}/db/production.sqlite3"
    run " -nfs #{shared_path}/config/ldap.yml #{release_path}/config/ldap.yml"
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  
  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  

  task :symlink_shared do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/config/Procfile #{release_path}/Procfile"
    run "ln -nfs #{shared_path}/config/.foreman #{release_path}/.foreman"
  end
  
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
end

namespace :unicorn do
  desc "Zero-downtime restart of Unicorn"
  task :restart, except: { no_release: true } do
    run "kill -s USR2 `cat /tmp/unicorn.[application's name].pid`"
  end
 
  desc "Start unicorn"
  task :start, except: { no_release: true } do
    run "cd #{current_path} ; bundle exec unicorn_rails -c config/unicorn.rb -D"
  end
 
  desc "Stop unicorn"
  task :stop, except: { no_release: true } do
    run "kill -s QUIT `cat /tmp/unicorn.[application's name].pid`"
  end
end

after "deploy:restart", "unicorn:restart"

before 'deploy:assets:precompile', 'deploy:symlink_shared'

before 'deploy:start', 'foreman:export'
after 'deploy:start', 'foreman:start'

before 'deploy:restart', 'foreman:export'
after 'deploy:restart', 'foreman:restart'
