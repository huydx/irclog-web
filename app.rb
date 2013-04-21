require 'rubygems'
require 'sinatra'
require 'sqlite3'
require 'fileutils'

use Rack::Logger
use Rack::Auth::Basic, "Restricted Area" do |usr, pw|
  usr == ENV['SINATRA_IRC_USR'] and pw == ENV['SINATRA_IRC_PWD']
end

helpers do
  def logger
    request.logger
  end
end

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
 
  def get_rows_by_nday(n)
    didx = @INDEXMAP["date"]
    dat = @db.execute("select date, user, content from #{@table} where (julianday(date(date)) = (julianday(date('now'))-#{n}+1)) order by date(date) desc")
    return nil if dat[0].nil?

    day = DateTime.parse(dat[0][didx]).strftime("%m/%d/%y")
    return {:day=>day, :data=>dat} 
  end

  def get_rows_all
    return @db.execute("select date, user, content from #{@table} order by date(date) desc")
  end
    
  def simple_format(row)
    didx, uidx, cidx = @INDEXMAP["date"], @INDEXMAP["user"], @INDEXMAP["content"]
    #format date 
    date = DateTime.parse(row[didx]).strftime("%T")
    
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
      current_date =  DateTime.parse(r[didx])
      current_day = current_date.day
      prev_day = current_date.day if idx == 0

      if (current_day - prev_day)!=0
        ret.push(nil)
      else
        to_append = 
        { 
          :date=>current_date.strftime("%T"), 
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

class IrcApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 5000
  
  configure :production, :development do
    enable :logging
  end

  get '/irc/:id' do 
    @id = Integer(params[:id])
    @title = 'irc log bot'
    @rows = []

    irc = IrcLog.new("irclog.db", "chatlog")
    case @id
    when 0
      day = 0
    when 1
      day = 1
    when 2 
      day = 2
    when 3
      day = 7
    when 4
      day = nil
    else
      day = 0
    end
    if day.nil?
      _rows = irc.get_rows_all()
    else
      ret = irc.get_rows_by_nday(day)
      unless ret.nil?
        _rows = ret[:data]
        @day = ret[:day]
      end
    end
    
    @rows = irc.color_format(_rows) unless _rows.nil?

    erb :home
  end

  get '/*' do
    redirect "/irc/0"
  end
end
