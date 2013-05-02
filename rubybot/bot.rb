require 'cinch'
require 'sqlite3'
require 'ruby-debug'
require 'yaml'

#class to store all configuration
module BmConfig
  #config file must be in the same folder
  @config = YAML.load_file("config.yml")
  def self.dbname
    @config["dbname"]
  end

  def self.dblocation
    @config["dblocation"]
  end 

  def self.ircserver
    @config["ircserver"]
  end

  def self.ircchannel
    @config["ircchannel"]
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

  def get_bookmark_from_days_before(from) 
    query = <<-SQL
    SQL
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
  def add_task_to_usr(desc, usr, date)
    query = <<-SQL
      INSERT INTO task
      (description, user_name, time)
      VALUES('#{desc}', '#{usr}', '#{date}')
    SQL
    @db.execute query
  end
  
  def show_by_usr(usr)
    query = <<-SQL
      SELECT t.description, t.time
      FROM task t
      WHERE t.usr_name = #{usr}
    SQL

    return (rows = @db.execute query)
  end

  def get_all_tasks()
    query = <<-SQL
      SELECT t.user_name, t.description, t.time
      FROM task t
    SQL

    return (rows = @db.execute query)
  end

  def get_today_tasks_of_usr(usr)
    query = <<-SQL
      SELECT t.user_name, t.description, t.time
      FROM task t
      WHERE (julianday('now') - julianday(t.time)) < 1
      WHERE t.user_name = #{usr}
    SQL

    return (rows = @db.execute query)
  end

  def get_near_task()
    hours_to_get = 1
    query = <<-SQL
      SELECT t.id, t.user_name, t.description, t.time
      FROM task t
      WHERE (julianday(t.time) - julianday('now', 'localtime')) < #{hours_to_get}.0/24
    SQL
    return (rows = @db.execute query)
  end

  def delete_by_task_id(id)
    @db.execute <<-SQL
      DELETE FROM task 
      WHERE id = #{id} 
    SQL
  end
end

class TaskPlugin 
  include Cinch::Plugin
  include BmConfig

  timer 10, method: :check_tasks

  def initialize(*args)
    super
    dbname = BmConfig::dbname
    dblocation = File.expand_path(BmConfig::dblocation)
    @sql_helper = TaskSqlHelper.new({:db=>(dblocation+"/"+dbname)})
  end 

  def check_tasks
    rows = @sql_helper.get_near_task()
    recipient = Channel(@bot.config.channels[0])
    unless rows.empty?
      rows.each { |r| #[user, desc, time]
        mes = "#{r[1]} has a task #{r[2]} at #{r[3]}" 
        recipient.send(mes)
        @sql_helper.delete_by_task_id(r[0])
      }
    end
  end

end

bot = Cinch::Bot.new do
  class << self
    def bookmark_sql_helper
      dbname = BmConfig::dbname
      dblocation = File.expand_path(BmConfig::dblocation)
      BookmarkSqlHelper.new({:db=>(dblocation+"/"+dbname)})
    end
    
    def task_sql_helper
      dbname = BmConfig::dbname
      dblocation = File.expand_path(BmConfig::dblocation)
      TaskSqlHelper.new({:db=>(dblocation+"/"+dbname)})
    end
  end

  bm_add_pattern = /^bm add (.*)/           #example: bm add [url] [#tag1] [#tag2]
  bm_delete_pattern = /^bm delete (.*)/     #example: bm delete [url]
  bm_show_url_pattern = /^bm show (.*)/     #example: bm show [#tag1] [#tag2]
  bm_show_tags_pattern = /^bm tags$/        #example: bm tags
  bm_show_help = /^bm help$/                #example: bm help
  
  task_add_pattern  = /^task add \[(.*)\] (.*) \[(.*)\]/    #example: task add [task-description] user [YYYY/MM/DD HHh] 
  task_show_user_pattern = /^task show (.*)/                #example: task show [username] 
  task_delete_pattern  = /^task delete (.*)/                #example: task delete [taskid]
  task_show_today = /^task show today$/                     #example: task show today


  configure do |c|
    c.server = BmConfig::ircserver
    c.channels = [BmConfig::ircchannel]
    c.plugins.plugins = [TaskPlugin]
  end
  

  #bookmark feature
  #current function include
  # -to add new url with tags   : bm add [url] [#tag1] [#tag2]
  # -to delete an url           : bm delete [url]
  # -to show url with tags      : bm show [#tag1] [#tag2]
  # -to show all tags of system : bm tags

  on :message, bm_add_pattern do |m|
    #note: this function is in scope of Cinch::Handler, not Cinch::Bot
    mes = m.params[1]
    usr = m.user.nick

    params = mes.scan(bm_add_pattern).join("").split
    url = params[0]
    tags = params[1..-1] 
    
    bot = self.bot
    begin 
      bot.bookmark_sql_helper.add_bookmark(usr, url, tags)
      m.reply "add done!"
    rescue
      m.reply "sql error!"
    end
  end

  on :message, bm_show_url_pattern do |m|
    mes = m.params[1]
    usr = m.user.nick

    tags = mes.scan(bm_show_url_pattern).join("").split
    tags.each {|t| m.reply "tags must be format as #something" if /^#(.*)/.match(t).nil? }

    bot = self.bot
    bm = bot.bookmark_sql_helper.get_bookmark_by_tag(usr, tags)
    bm.each do |row|
      m.reply row.flatten.join(" ")
    end    
  end

  on :message, bm_show_tags_pattern do |m|
    bot = self.bot
    rows = bot.bookmark_sql_helper.get_tags_all().flatten
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

  #task alarm feature
  #current function include
  # - task add [[task-descriotion]] [user] (date(unix format) | days(from now))
  # - task show [username] 
  # - task delete [taskid]
  on :message, task_add_pattern do |m|
    require 'date'
    require 'debugger'
    begin
      mes = m.params[1]
      params = mes.scan(task_add_pattern).flatten

      desc = params[0]
      user = params[1]
      date = (params[2].split)[0].split("/") #[TODO] think about smarter way 
      hour = (params[2].split)[1]
      
      m.reply "hour format must be like 12h (end with h)" unless hour.end_with?("h")
      hour = hour.chop #remove "h"
      m.reply "hour must be number" unless /^[\d]+$/ === hour
      hour = hour.to_i

      year, month, day = date.map{|e| e.to_i}

      m.reply "date format must be YYYY/MM/DD" unless (year & month & day)
    rescue
      m.reply "there is something wrong with your format, please 'task help'"
    end

    date_unix = DateTime.new(year, month, day, hour).strftime("%Y-%m-%d %H:%M:%S")
    bot.task_sql_helper.add_task_to_usr(desc, user, date_unix)
  end

  on :message, task_show_user_pattern do |m|
    mes = m.params[1]  
    user = mes.scan(task_show_user_pattern).flatten.join("")

    rows = bot.task_sql_helper.show_by_usr(user)
    rows.each { |r|
      m.reply r.flatten.join("   ")
    }
  end
  
  on :message, task_show_today do |m|
    tasks = bot.task_sql_helper.get_today_tasks_of_usr(m.user.nick)
    tasks.each { |t|
      mes = "#{t[0]} has a task #{t[1]} at #{t[2]}"
      m.reply mes
    }
  end

  on :message, task_delete_pattern do |m|
    #[TODO]
  end
end

bot.start
