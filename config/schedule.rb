# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

set :output, "/rails/log/cron.log"

every 4.hours do
  runner "PeriodicSyncAndProcessJob.perform_later"
end
