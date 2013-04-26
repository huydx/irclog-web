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
      tags.each do |t| 
        tag_exist = @db.execute "select id from tag where name='#{t}'"
        if tag_exist.empty?
          ret = @db.execute <<-SQL
            INSERT OR IGNORE 
            INTO tag(name) 
            VALUES('#{t}')
          SQL
          tag_ids.push (@db.execute "select last_insert_rowid()").join("").to_i
        else 
          tag_ids.push tag_exist.join("").to_i
        end
      end
    end
    
    bookmark_exist = @db.execute "select id from bookmark where url='#{url}' and user_name='#{usr}'"
    if bookmark_exist.empty?
      @db.execute <<-SQL
        INSERT OR IGNORE INTO 
        bookmark(url, user_name, time_created) 
        VALUES('#{url}', '#{usr}', date('now'))
      SQL
      bm_id = (@db.execute "SELECT LAST_INSERT_ROWID()").join("").to_i
    else
      bm_id = (bookmark_exist.flatten)[0]
    end

    unless tag_ids.empty? || bm_id.nil?
      tag_ids.each do |tid| 
        map_exist = @db.execute "SELECT ID FROM tagmap WHERE bookmark_id=#{bm_id} AND tag_id=#{tid}"
        if map_exist.empty?
          @db.execute <<-SQL
            INSERT INTO tagmap
            (bookmark_id, tag_id)
            VALUES(#{bm_id}, #{tid})
          SQL
        end
      end
    end
  end

  def get_bookmark_by_tag(user, tags=[])
    tags = "(#{tags.map{ |t| %Q('#{t}') }.join(',')})"
    query = <<-SQL
      SELECT b.url, b.time_created
      FROM tagmap bt, bookmark b, tag t
      WHERE bt.tag_id = t.id
      AND (t.name IN #{tags})
      AND b.id = bt.bookmark_id
      AND b.user_name = '#{user}'
      GROUP BY b.id
    SQL
    return (rows = @db.execute query)
  end

  def get_bookmark_by_day(from, to) 

  end

  def get_tags_all()
    query = <<-SQL
      SELECT DISTINCT t.name
      FROM tag t
    SQL
    return (rows = @db.execute query)
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

  bm_add_pattern = /^bm add (.*)/           #example: bm add [url] [#tag1] [#tag2]
  bm_delete_pattern = /^bm delete (.*)/     #example: bm delete [url]
  bm_show_url_pattern = /^bm show (.*)/     #example: bm show [#tag1] [#tag2]
  bm_show_tags_pattern = /^bm tags$/        #example: bm tags
  bm_show_help = /^bm help$/                #example: bm help

  configure do |c|
    c.server = server
    c.channels = [channel]
    c.plugins.plugins = [TaskPlugin]
  end

  on :message, bm_add_pattern do |m|
    #note: this function is in scope of Cinch::Handler, not Cinch::Bot
    mes = m.params[1]
    usr = m.user.nick

    params = mes.scan(bm_add_pattern).join("").split
    url = params[0]
    tags = params[1..-1] 
    
    bot = self.bot
    begin 
      bot.sql_helper.add_bookmark(usr, url, tags)
      m.reply "add done!"
    rescue
      m.reply "sql error!"
    end
  end

  on :message, bm_show_url_pattern do |m|
    mes = m.params[1]
    usr = m.user.nick

    tags = mes.scan(bm_show_url_pattern).join("").split

    bot = self.bot
    bm = bot.sql_helper.get_bookmark_by_tag(usr, tags)
    bm.each do |row|
      m.reply row.flatten.join(" ")
    end    
  end

  on :message, bm_show_tags_pattern do |m|
    bot = self.bot
    rows = bot.sql_helper.get_tags_all().flatten
    m.reply rows.join(" ")
  end

  on :message, bm_delete_pattern do |m|
  end
  
  on :message, bm_show_help do |m|
    message = <<-MES
      -to add new url with tags   : bm add [url] [#tag1] [#tag2]
      -to delete an url           : bm delete [url]
      -to show url with tags      : bm show [#tag1] [#tag2]
      -to show all tags of system : bm tags
    MES
    m.reply message
  end
end

bot.start
