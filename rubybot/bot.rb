require 'cinch'
require 'sqlite3'

server = "irc.freenode.org"
channel = "#huydxcinch"

class SqlHelper
  def initialize options={}
    dbpath = options[:db]
    @db = SQLite3::Database.new(dbpath)
  end
end


class BookmarkSqlHelper < SqlHelper
  def add_bookmark(url, description, tags=[])

  end

  def get_bookmark_by_tag(tags=[])

  end

  def get_bookmark_by_day(from, to) 

  end
end

class TaskSqlHelper < SqlHelper
  def get_task(usr)

  end
end

class TaskPlugin 
  include Cinch::Plugin

  timer 60, method: :check_tasks

  def initialize(*args)
    super
    dbname = ENV['CINCH_DBNAME']
    dblocation = File.expand_path("~/Dropbox/db/")   
    @sql_helper = BookmarkSqlHelper.new({:db=>(dblocation+"/"+dbname)})
  end 

  def check_tasks

  end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server = server
    c.channels = [channel]
    c.plugins.plugins = [TaskPlugin]
  end

  on :message, /^bm add (.*)/ do |m|
     m.reply "Hello, #{m.user.nick}"
  end

  on :message, /^bm delete (.*)/ do |m|
     m.reply "Hello, #{m.user.nick}"
  end

  on :message, /^bm show (.*)/ do |m|
     m.reply "Hello, #{m.user.nick}"
  end
end

bot.start
