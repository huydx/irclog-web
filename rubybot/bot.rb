require 'cinch'
require 'sqlite3'
require 'ruby-debug'

server = "irc.freenode.org"
channel = "#huydxcinch"

module BmConfig
  @dbname = ENV['CINCH_DBNAME']
  @dblocation = File.expand_path("~/Dropbox/db/")

  def self.dbname
    @dbname
  end

  def self.dblocation
    @dblocation
  end 
end


class SqlHelper
  def initialize options={}
    dbpath = options[:db]
    @db = SQLite3::Database.new(dbpath)
  end
end


class BookmarkSqlHelper < SqlHelper
  def add_bookmark(usr, url, tags=[])
    tag_ids = []
    unless tags.empty? 
      tags.each {|t| @db.execute ("insert into tag name values(#{t})") }
      tag_ids.push (@db.execute "select last_insert_rowid()")
    end
    @db.execute ("insert into bookmark (url, user_name, time_created) (#{url}, #{usr}, datetime(now))")
    bm_id = @db.execute "select last_insert_rowid()"
    
    unless tag_ids.empty?
      tag_ids.each { |tid| 
        @db.execute ("insert into tagmap (bookmark_id, tag_id) values(#{bm_id}, #{tid})") 
      } 
    end
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
  include BmConfig

  timer 60, method: :check_tasks

  def initialize(*args)
    super
    dbname = BmConfig::dbname
    dblocation = BmConfig::dblocation   
    @sql_helper = BookmarkSqlHelper.new({:db=>(dblocation+"/"+dbname)})
  end 

  def check_tasks

  end
end

bot = Cinch::Bot.new do
  class << self
    def sql_helper
      dbname = BmConfig::dbname
      dblocation = BmConfig::dblocation   
      BookmarkSqlHelper.new({:db=>(dblocation+"/"+dbname)})
    end
  end

  bm_add_pattern = /^bm add (.*)/
  bm_delete_pattern = /^bm delete (.*)/
  bm_show_pattern = /^bm show (.*)/

  configure do |c|
    c.server = server
    c.channels = [channel]
    c.plugins.plugins = [TaskPlugin]
  end

  on :message, bm_add_pattern do |m|
    mes = m.params[1]
    usr = m.user.nick

    params = mes.scan(bm_add_pattern).join("").split
    url = params[0]
    tags = params[1..-1] 
    
    bot = self.bot
    bot.sql_helper.add_bookmark(usr, url, tags)
  end

  on :message, bm_delete_pattern do |m|
    m.reply "Hello, #{m.user.nick}"
  end

  on :message, bm_show_pattern do |m|
    m.reply "Hello, #{m.user.nick}"
  end
end

bot.start
