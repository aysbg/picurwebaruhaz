root = "/home/gwuix2/picurwebaruhaz/current"
working_directory root
pid "#{root}/tmp/pids/unicorn.pid"
stderr_path "#{root}/log/unicorn.log"
stdout_path "#{root}/log/unicron.log"

listen "/tmp/unicorn.blog.sock"
worker_processes 2
timeout 30
