require 'sqlite3'
require 'sqlhelper.rb'

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
