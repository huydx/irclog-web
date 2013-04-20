require 'rubygems'
require 'sinatra'
require 'sqlite3'
require 'fileutils'

set :port, 5000

class IrcLog
  @www_folder = "./"

  def initialize(dbname, table)
    @table = table
    
    copy_db_to_local(dbname)

    @db = SQLite3::Database.new("#{dbname}")
    @INDEXMAP = {"date"=>0, "user"=>1, "content"=>2}
  end
  
  def copy_db_to_local(dbname)
    FileUtils.cp(File.expand_path("~/Dropbox/db/")+"/#{dbname}", Dir.pwd)
  end

  def get_rows
    return @db.execute("select date, user, content from #{@table} order by date(date) desc")
  end
    
  def simple_format(row)
    didx, uidx, cidx = @INDEXMAP["date"], @INDEXMAP["user"], @INDEXMAP["content"]
    #format date 
    date = DateTime.parse(row[didx]).strftime("posted:[%Y %m %d %T]")
    
    return {:date=>date, :user=>row[uidx], :content=>row[cidx]} 
  end  
  
  def color_format(rows)
    didx, uidx, cidx = @INDEXMAP["date"], @INDEXMAP["user"], @INDEXMAP["content"]
    color_hash_table = {}
    ret = []

    uniq_usr = rows.map{ |r| r[uidx]}.uniq

    idx = 0
    uniq_usr.each do |u|
      u_integer = 0
      
      r = rand(255).to_s(16)
      g = rand(255).to_s(16)
      b = rand(255).to_s(16)

      r, b, g = [r, b, g].map { |s| if s.size == 1 then '0' + s else s end }      

      color_hash_table[u] = r + g + b
      idx += 1
    end 

    idx = 0
    prev_day = ""
    rows.each do |r|
      p r
      current_date =  DateTime.parse(r[didx])
      current_day = current_date.day
      prev_day = current_date.day if idx == 0

      if (current_day - prev_day)!=0
        ret.push(nil)
      else
        to_append = 
        { 
          :date=>current_date.strftime("posted:[%Y %m %d %T]"), 
          :user=>{:name=>r[uidx], :color=>color_hash_table[r[uidx]]}, 
          :content=>r[cidx]
        }
      end
      
      ret.push(to_append)
      prev_day = current_day
      idx += 1
    end 
    return ret
  end
end

get '/irc' do 
  @title = 'irc log bot'
  @rows = []
  irc = IrcLog.new("irclog.db", "chatlog")
  _rows = irc.get_rows()
  @rows = irc.color_format(_rows)

  erb :home
end

get '/*' do
  redirect "/irc"
end
