require 'sqlite3'
require 'sqlhelper.rb'

class TaskSqlHelper < SqlHelper
  require 'debugger'

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
      SELECT t.id, t.description, t.time
      FROM task t
      WHERE t.user_name = '#{usr}'
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
      WHERE (julianday('now', 'localtime') - julianday(t.time)) < 1
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

