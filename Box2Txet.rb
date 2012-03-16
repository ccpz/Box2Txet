require 'net/http'
require 'rexml/document'

def tag_convert(str)
	str.gsub(/^<br\/>/, "").gsub(/<br\/>/, "\n").gsub(/<b>(.*?)<\/b>:/, '  \1:').gsub(/<b>(.*?)<\/b>/, '\1')
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
		linebuf<<tag_convert(e.text).gsub(/(.*:)/, "\033[1;33m"+'\1'+"\033[m")
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

def hr(doc)
end

url = 'http://gd2.mlb.com/components/game/mlb/'<<ARGV[0]

#linescore
xml_data = Net::HTTP.get_response(URI.parse(url+'/miniscoreboard.xml')).body
doc = REXML::Document.new(xml_data)

linebuf = []
linebuf[1] = sprintf("\033[1;31;42m%s (%d-%d)\033[m ", doc.root.attributes['away_name_abbrev'], doc.root.attributes['away_win'], doc.root.attributes['away_loss'])
linebuf[2] = sprintf("\033[1;34;43m%s (%d-%d)\033[m ", doc.root.attributes['home_name_abbrev'], doc.root.attributes['home_win'], doc.root.attributes['home_loss'])
linebuf[0] = ' '*10+"\033[1;31m"
(1..9).each {|i| linebuf[0]<<sprintf("%3d",i)} 
linebuf[0] << "\033[m  R  H  E"

doc.elements.each('game/linescore/inning') do |inn|
	if(inn.attributes['away'].to_i>0)
		linebuf[1]<<sprintf("\033[1;33m%3d\033[m", inn.attributes['away'])
	else
		linebuf[1]<<sprintf("%3d", inn.attributes['away'])
	end
	if(inn.attributes['home'])
		if(inn.attributes['home'].to_i>0)
			linebuf[2]<<sprintf("\033[1;33m%3d\033[m", inn.attributes['home'])
		else
			linebuf[2]<<sprintf("%3d", inn.attributes['home'])
		end
	else
		linebuf[2]<<'  X'
	end
end

e=doc.root.elements['linescore']
linebuf[1]<<sprintf("%3d%3d%3d", e.elements['r'].attributes['away'], e.elements['h'].attributes['away'], e.elements['e'].attributes['away'])
linebuf[2]<<sprintf("%3d%3d%3d", e.elements['r'].attributes['home'], e.elements['h'].attributes['home'], e.elements['e'].attributes['home'])

linebuf<<''

#wp, lp,

e = doc.root.elements['post_game'].elements['winning_pitcher'] 
linebuf<<sprintf("W: %s (%d-%d ERA %s)", e.attributes['name_display_roster'], e.attributes['wins'], e.attributes['losses'], e.attributes['era'])

e = doc.root.elements['post_game'].elements['losing_pitcher']
linebuf<<sprintf("L: %s (%d-%d ERA %s)", e.attributes['name_display_roster'], e.attributes['wins'], e.attributes['losses'], e.attributes['era'])

e = doc.root.elements['post_game'].elements['save_pitcher']
if(e)
    linebuf<<sprintf("SV: %s (%d-%d %d S ERA %s)", e.attributes['name_display_roster'], e.attributes['wins'], e.attributes['losses'], e.attributes['saves'], e.attributes['era'])
end

xml_data = Net::HTTP.get_response(URI.parse(url+'/boxscore.xml')).body
doc = REXML::Document.new(xml_data)
linebuf<<hitter(doc, "away")
linebuf<<pitcher(doc, "away")
linebuf<<hitter(doc, "home")
linebuf<<pitcher(doc, "home")

doc.elements.each('boxscore/game_info') do |e|
	linebuf<<tag_convert(e.text)
end
puts linebuf
