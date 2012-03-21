require 'net/http'
require 'rexml/document'

require 'terminal-table/import'

def wrap(s, width=60)
  s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
end

def tag_convert(str)
	str = str.gsub(/^<br\/>/, "").gsub(/<br\/>/, "\n").gsub(/<b>(.*?)<\/b>:/, '  \1:').gsub(/<b>(.*?)<\/b>/, '\1').gsub(/(.*:)/, "\033[1;33m"+'\1'+"\033[m")
	ret_str='';
	str.each_line {|s| ret_str+=wrap(s)}
	return ret_str
end

def hitter_header(team)
	str=sprintf("\033[1;32;45m%-25s", team)
	['AB', 'R', 'H', 'RBI', 'BB', 'SO', 'LOB', '  AVG'].each {|x|
		str<<sprintf("%4s", x)
	}
	str<<"\033[m"
end

def hitter(doc, filter)
	linebuf = []
	linebuf<<''<<hitter_header(doc.root.attributes[filter+'_sname'])
	doc.elements.each('boxscore/batting[@team_flag="'+filter+'"]/batter') do |e|
		next if e.attributes['bo']==nil
		name = e.attributes['name']+", "+e.attributes['pos']
		if(e.attributes['note']!=nil)
			name = e.attributes['note']+name
		end
		if(e.attributes['bo'].to_i%10>0)
			name = ' '+name
		end
		ab = e.attributes['ab']
		r = e.attributes['r']
		h = e.attributes['h']
		rbi = e.attributes['rbi']
		bb = e.attributes['bb']
		so = e.attributes['so']
		lob = e.attributes['lob']
		avg = e.attributes['avg']
		    linebuf<<sprintf("%-25s%4s%4s%4s%4s%4s%4s%4s %4s", name, ab, r, h, rbi, bb, so, lob, avg)
	end
    doc.elements.each('boxscore/batting[@team_flag="'+filter+'"]') do |e|
        ab = e.attributes['ab']
        r = e.attributes['r']
        h = e.attributes['h']
        rbi = e.attributes['rbi']
        bb = e.attributes['bb']
        so = e.attributes['so']
        lob = e.attributes['lob']
        avg = e.attributes['avg']
            linebuf<<sprintf("\033[1;32;45m%-25s%4s%4s%4s%4s%4s%4s%4s %4s\033[m", '', ab, r, h, rbi, bb, so, lob, avg)
    end
	linebuf<<'';
	doc.elements.each('boxscore/batting[@team_flag="'+filter+'"]/note') do |e|
		linebuf<<tag_convert(e.to_a.join("").gsub(/\n/, '')).gsub(/\. */, "\n")<<""
	end
	doc.elements.each('boxscore/batting[@team_flag="'+filter+'"]/text_data') do |e|
		linebuf<<tag_convert(e.text)
	end
	linebuf
end

def pitcher_header(team)
	str=sprintf("\033[1;32;45m%-25s", team)
	['IP', 'H', 'R', 'ER', 'BB', 'SO', 'HR', '   ERA'].each {|x|
		str<<sprintf("%4s", x)
	}
	str<<"\033[m"
end

def pitcher(doc, filter)
    linebuf = []
    linebuf<<''<<pitcher_header(doc.root.attributes[filter+'_sname'])
    doc.elements.each('boxscore/pitching[@team_flag="'+filter+'"]/pitcher') do |e|
		name = e.attributes['name']
		if(e.attributes['note']!=nil)
			name<<' '<<e.attributes['note']
		end
		ip = sprintf("%d.%d", e.attributes['out'].to_i/3, e.attributes['out'].to_i%3)
		h = e.attributes['h']
		r = e.attributes['r']
		er = e.attributes['er']
		bb = e.attributes['bb']
		so = e.attributes['so']
		hr = e.attributes['hr']
		era = e.attributes['era']
            linebuf<<sprintf("%-25s%4s%4s%4s%4s%4s%4s%4s%6s", name, ip,  h, r, er, bb, so, hr, era)
    end

    doc.elements.each('boxscore/pitching[@team_flag="'+filter+'"]') do |e|
        ip = sprintf("%d.%d", e.attributes['out'].to_i/3, e.attributes['out'].to_i%3)
        h = e.attributes['h']
        r = e.attributes['r']
        er = e.attributes['er']
        bb = e.attributes['bb']
        so = e.attributes['so']
        hr = e.attributes['hr']
        era = e.attributes['era']
        linebuf<<sprintf("\033[1;32;45m%-25s%4s%4s%4s%4s%4s%4s%4s%6s\033[m", '', ip,  h, r, er, bb, so, hr, era)
    end
    linebuf
end

def scoring_summary(doc, away, home)
	table = Terminal::Table.new
	table.style = {:width => 80}
	table.headings = [away, home, '']
	inning=''
	REXML::XPath.each( doc, "//atbat[@away_team_runs]") do |e|
		away_score = e.attributes['away_team_runs'].to_s
		home_score = e.attributes['home_team_runs'].to_s
		if(e.parent.name.to_s=="top")
			away_score = "\033[1;33m"+away_score+"\033[m"
		else
			home_score = "\033[1;33m"+home_score+"\033[m"
		end
		inning_str = e.parent.name+' '+e.parent.parent.attributes['num']
		if(inning_str!=inning)
			if(inning!='')
				table.add_separator
			end
			table.add_row [{:value => "\033[1;32m"+inning_str+"\033[m", :colspan => 3}]
			table.add_separator
			inning=inning_str
		end
		table.add_row [away_score, home_score, wrap(e.attributes['des'].gsub(/ +/, ' '))]
	end
	return table.to_s
end

url = 'http://gd2.mlb.com/components/game/mlb/'<<ARGV[0]
away_name=''
home_name=''
#linescore
xml_data = Net::HTTP.get_response(URI.parse(url+'/miniscoreboard.xml')).body
doc = REXML::Document.new(xml_data)

rows =[[], []]
head =['']
end_inning = doc.root.elements['game_status'].attributes['inning'].to_i
head.concat((1..end_inning).to_a)
head.concat(['R', 'H', 'E'])
away_name=doc.root.attributes['away_name_abbrev']
home_name=doc.root.attributes['home_name_abbrev']
rows[0] << sprintf("\033[1;31;42m%s (%d-%d)\033[m", away_name, doc.root.attributes['away_win'], doc.root.attributes['away_loss'])
rows[1] << sprintf("\033[1;34;43m%s (%d-%d)\033[m", home_name, doc.root.attributes['home_win'], doc.root.attributes['home_loss'])

map = {'away'=>0, 'home'=>1}

doc.elements.each('game/linescore/inning') do |inn|
	['away', 'home'].each do |i|
		if(inn.attributes[i]==nil)
			rows[map[i]]<<'X'
		elsif(inn.attributes[i].to_i>0)
			rows[map[i]]<<sprintf("\033[1;33m%d\033[m", inn.attributes[i])
		else
			rows[map[i]]<<inn.attributes[i]
		end
	end
end

e=doc.root.elements['linescore']
['r', 'h', 'e'].each do |i|
	['away', 'home'].each do |j|
		rows[map[j]]<<e.elements[i].attributes[j]
	end
end

table = Terminal::Table.new :headings => head, :rows => rows
table.style = {:padding_left => 2}

puts table

#wp, lp,

e = doc.root.elements['post_game'].elements['winning_pitcher'] 
printf("\033[1;31mW: %s (%d-%d ERA %s)\033[m", e.attributes['name_display_roster'], e.attributes['wins'], e.attributes['losses'], e.attributes['era'])

e = doc.root.elements['post_game'].elements['losing_pitcher']
printf("  \033[1;32mL: %s (%d-%d ERA %s)\033[m", e.attributes['name_display_roster'], e.attributes['wins'], e.attributes['losses'], e.attributes['era'])

e = doc.root.elements['post_game'].elements['save_pitcher']
if(e)
    printf("   \033[1;33mSV: %s (%d-%d %d S)\033[m", e.attributes['name_display_roster'], e.attributes['wins'], e.attributes['losses'], e.attributes['saves'], e.attributes['era'])
end

puts

xml_data = Net::HTTP.get_response(URI.parse(url+'/game_events.xml')).body
doc = REXML::Document.new(xml_data)

puts scoring_summary(doc, away_name, home_name)

xml_data = Net::HTTP.get_response(URI.parse(url+'/boxscore.xml')).body
doc = REXML::Document.new(xml_data)
puts hitter(doc, "away")
puts pitcher(doc, "away")
puts hitter(doc, "home")
puts pitcher(doc, "home")

e=doc.root.elements['game_info']
if(e)
	puts tag_convert(e.text)
end
