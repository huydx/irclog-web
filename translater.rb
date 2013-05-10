require 'sqlite3'

class Translater
  def self.do(source)
    require 'google_drive'
    require 'rack/contrib/jsonp'
    require 'json'
    require 'rack/contrib/jsonp'

    session = GoogleDrive.login(ENV['GOOGLE_ID'], ENV['GOOGLE_PASSWD'])
    ws = session.spreadsheet_by_key(ENV['SPREADSHEET_KEY']).worksheets[0]

    max_row_num = 1000
    row = 0

    from = 'ja' # Optional
    to = 'en' 
    texts = source
    result = {}

    texts = [texts] if texts.is_a? String
    row = (row + 1) % max_row_num 

    if from.nil?
      ws[row, 1] = "=DetectLanguage(\"#{texts[0]}\")"
      from = "A#{row}"
    else
      from = "\"#{from}\""
    end

    # Call script from spreadsheet
    texts.each_with_index do |text, index|
      ws[row, index + 2] = "=GoogleTranslate(\"#{text}\", #{from}, \"#{to}\")"
    end
    
    # Save and reload the worksheet to get my changes effect
    begin
      ws.save
      ws.reload
      
      texts.each_with_index do |text, index|
        result[text] = ws[row, index + 2]
      end
      ret = "" 
      result.each_value { |v| ret = v }
      return ret 
    rescue Exception=>e
      p source
    end
  end
end
