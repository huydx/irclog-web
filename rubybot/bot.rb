require 'cinch'
require 'sqlite3'


server = "irc.freenode.org"
channel = "#ktmt.github"

class BookmarkSqlHelper
  def initialize options={}
    dbpath = options[:db]
    @db = SQLite3::Database.new(dbpath)
  end
  
  def add_bookmark(url, description, tags=[])

  end

  def get_bookmark_by_tag(tags=[])

  end

  def get_bookmark_by_day(from, to) 

  end
end

class IrcBookmarkPlugin
  include Cinch::Plugin
  match /^bm add .+/,       method: :add_bm
  match /^bm show .+/,      method: :show_bm
  match /^bm del .+/,       method: :delete_bm
  match /^task add .+/,     method: :add_task 

  timer 60,                 method: :check_task_time

  def initialize(*args)
    super
    dbname = ENV['CINCH_DBNAME']
    dblocation = File.expand_path("~/Dropbox/db/")   
    @sql_helper = BookmarkSqlHelper.new({:db=>(dblocation+"/"+dbname)})
  end 

  def add(m, channel)
    p m
  end

  def show(m, channel)
    p m
  end

  def delete(m, channel)
    p m
  end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server = server
    c.channels = [channel]
    c.plugins.plugins = [IrcBookmarkPlugin]
  end
end

bot.start
