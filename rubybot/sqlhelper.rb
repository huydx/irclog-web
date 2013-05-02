class SqlHelper
  def initialize options={}
    dbpath = options[:db]
    @db = SQLite3::Database.new(dbpath)
  end
end
