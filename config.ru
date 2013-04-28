$:.unshift File.dirname(__FILE__)

require "./app"

log = File.new("log.txt", "a+") 
$stdout.reopen(log)
$stderr.reopen(log)

$stderr.sync = true
$stdout.sync = true

run IrcApp
