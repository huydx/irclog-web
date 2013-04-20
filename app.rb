require 'rubygems'
require 'sinatra'
require 'sqlite3'

set :port, 5000

class IrcLog
  def initialize(dbname, table)
    @db = SQLite3::Database.new("#{Dir.pwd}/#{dbname}")
    @table = table
    @INDEXMAP = {"date"=>0, "user"=>1, "content"=>2}
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
    uniq_usr = rows.map{ |r| r[uidx]}.uniq
    color_hash_table = {}
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

    return rows.map do |r| 
      { 
        :date=>DateTime.parse(r[didx]).strftime("posted:[%Y %m %d %T]"), 
        :user=>{:name=>r[uidx], :color=>color_hash_table[r[uidx]]}, 
        :content=>r[cidx]
      }
    end 
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
  "go to /irc to see irc log"
end
