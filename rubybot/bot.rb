$:.unshift File.dirname(__FILE__)

require 'cinch'
require 'sqlite3'
require 'ruby-debug'
require 'bmconfig.rb'
require 'bookmarksql.rb'
require 'tasksql.rb'

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
  task_help = /^task help$/                                 #example: task help


  configure do |c|
    c.server = BmConfig::ircserver
    c.channels = [BmConfig::ircchannel]
    c.nick = BmConfig::botname
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
    m.reply "task added!"
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
    mes = m.params[1]  
    id = mes.scan(task_delete_pattern).flatten.join("").to_i
    begin 
      rows = bot.task_sql_helper.delete_by_task_id(id)
    rescue
      m.reply "sql error!"
    end
    m.reply "delete done!"
  end

  on :message, task_help do |m|
    mes = <<-MESSAGE
      - task add [[task-descriotion]] [user] (YYYY/MM/DD HHh)
      - task show [username] 
      - task delete [taskid]
    MESSAGE
    m.reply mes
  end
end

bot.start
