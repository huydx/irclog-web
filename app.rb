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
    
  def parse_row(row)
    didx, uidx, cidx = @INDEXMAP["date"], @INDEXMAP["user"], @INDEXMAP["content"]
    return {:date=>row[didx], :user=>row[uidx], :content=>row[cidx]} 
  end  
end

get '/irc' do 
  @title = 'irc log bot'
  @rows = []
  irc = IrcLog.new("irclog.db", "chatlog")
  _rows = irc.get_rows()
  _rows.each { |r| @rows.push (irc.parse_row(r)) }

  erb :home
end
