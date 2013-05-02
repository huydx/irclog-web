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

  def self.botname
    @config["botname"]
  end
end



