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
ssh_options[:forward_agent] = true



namespace :deploy do
   task :start do ; end
   task :stop do ; end
   task :restart, :roles => :app, :except => { :no_release => true } do
     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
   end
    %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
      task command, roles: :app, except: {no_release: true} do
        run "/etc/init.d/unicorn_#{application} #{command}"
      end
    end


  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    run "mkdir -p #{shared_path}/config"
  end
  
  
  task :create_symlinks do
    run "ln -nfs #{shared_path}/config/ldap.yml #{release_path}/config/ldap.yml"
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

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
end


namespace :unicorn do
  desc "Zero-downtime restart of Unicorn"
  task :restart, except: { no_release: true } do
    run "kill -s USR2 `cat /tmp/unicorn.[application's name].pid`"
    puts "Unicorn - 1"
  end
 
  desc "Start unicorn"
  task :start, except: { no_release: true } do
    run "cd #{current_path} ; bundle exec unicorn_rails -c config/unicorn.rb -D"
    "Unicorn - 2"
  end
 
  desc "Stop unicorn"
  task :stop, except: { no_release: true } do
    run "kill -s QUIT `cat /tmp/unicorn.[application's name].pid`"
    "Unicorn - 3"
  end
end

before "deploy:assets:precompile", "deploy:symlink_shared"
before "deploy", "deploy:check_revision"
after "deploy:restart", "deploy:cleanup"
after "deploy:restart", "unicorn:restart"
after "deploy:setup", "deploy:setup_config"
after "deploy:finalize_update", "deploy:symlink_config"

 namespace :assets do

    task :precompile, :roles => :web do
      from = source.next_revision(current_revision)
      if capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ lib/assets/ app/assets/ | wc -l").to_i > 0
        run_locally("rake assets:clean && rake assets:precompile")
        run_locally "cd public && tar -jcf assets.tar.bz2 assets"
        top.upload "public/assets.tar.bz2", "#{shared_path}", :via => :scp
        run "cd #{shared_path} && tar -jxf assets.tar.bz2 && rm assets.tar.bz2"
        run_locally "rm public/assets.tar.bz2"
        run_locally("rake assets:clean")
      else
        logger.info "Skipping asset precompilation because there were no asset changes"
      end
    end

    task :symlink, roles: :web do
      run ("rm -rf #{latest_release}/public/assets &&
            mkdir -p #{latest_release}/public &&
            mkdir -p #{shared_path}/assets &&
            ln -s #{shared_path}/assets #{latest_release}/public/assets")
    end
  end
