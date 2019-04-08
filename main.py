#!/usr/bin/env python3
import sys
import argparse
import logging
import urllib.request
import ujson
import re
from beautifultable import *
import textwrap 
import unicodedata

logger = logging.getLogger('spam_application')
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
ch = logging.StreamHandler()
ch.setFormatter(formatter)
logger.setLevel(logging.DEBUG)
logger.addHandler(ch)

def remove_accent(s):
    return ''.join((c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn'))

def linescore(game):
    table = BeautifulTable(default_alignment=ALIGN_RIGHT, default_padding=2)
    hdr = [0]
    data=[[], []]
    away=0
    home=1
    data[away].append("\033[1;33;41m%s (%s-%s)\033[m"%(game['away_name_abbrev'], game['away_win'], game['away_loss']))
    data[home].append("\033[1;37;44m%s (%s-%s)\033[m"%(game['home_name_abbrev'], game['home_win'], game['home_loss']))
    for inning in game['linescore']['inning']:
        hdr.append(str(int(hdr[-1])+1))
        if inning['away'].isdigit() and int(inning['away'])>0:
            data[away].append("\033[1;33m"+inning['away']+"\033[m")
        else:
            data[away].append(inning['away'])

        if inning['home'].isdigit() and int(inning['home'])>0:
            data[home].append("\033[1;33m"+inning['home']+"\033[m")
        else:
            data[home].append(inning['home'])
    
    hdr[0]=''
    hdr+=['\033[1;31mR', '\033[1;31mH', '\033[1;31mE\033[m']
    table.column_headers = hdr
    data[away]+=["\033[1;36m"+game['linescore']['r']['away'], "\033[1;36m"+game['linescore']['h']['away'], "\033[1;36m"+game['linescore']['e']['away']+"\033[m"]
    data[home]+=["\033[1;36m"+game['linescore']['r']['home'], "\033[1;36m"+game['linescore']['h']['home'], "\033[1;36m"+game['linescore']['e']['home']+"\033[m"]
    table.append_row(data[away])
    table.append_row(data[home])
    table.set_style(BeautifulTable.STYLE_NONE)
    print(table)

def scoring_summary(game):
    global logger
    table = BeautifulTable(default_alignment=ALIGN_LEFT)
    wrapper = textwrap.TextWrapper(width=50)
    url = 'https://gd2.mlb.com%s/game_events.json'%(game['game_data_directory'])
    score=dict()
    score['top']=0
    score['bottom']=0
    logger.info('parsing game event: %s', url)
    r = urllib.request.urlopen(url).read()
    events = ujson.loads(r.decode('utf-8'))
    event_table = []
    table.set_style(BeautifulTable.STYLE_NONE)
    table.column_headers = ["\033[1;33m"+events['data']['game']['inning'][0]['away_team'].upper(), "\033[1;33m"+events['data']['game']['inning'][0]['home_team'].upper(), '']
    first_of_inning = True
    for inning in events['data']['game']['inning']:
        for name in ['top', 'bottom']:
            first_of_inning = True
            for ab in inning[name]['atbat']:
                if name=='top' and int(ab['away_team_runs'])!=score['top']:
                    if first_of_inning:
                        table.append_row(["\033[1;32mtop {}\033[m".format(inning['num']), '', ''])
                        first_of_inning=False
                    score['top']=int(ab['away_team_runs'])
                    table.append_row(["\033[1;33m"+str(score['top'])+"\033[m", score['bottom'], remove_accent("\n".join(wrapper.wrap(text=ab['des'].replace('  ', ' '))))])
                if name=='bottom' and int(ab['home_team_runs'])!=score['bottom']:
                    if first_of_inning:
                        table.append_row(["\033[1;32mbottom {}\033[m".format(inning['num']), '', ''])
                        first_of_inning=False
                    score['bottom']=int(ab['home_team_runs'])
                    table.append_row([score['top'], "\033[1;33m"+str(score['bottom'])+"\033[m", remove_accent("\n".join(wrapper.wrap(text=ab['des'].replace('  ', ' '))))])
    print(table)
    print()

def hitter(data, team):
    table = BeautifulTable(default_alignment=ALIGN_RIGHT, max_width=70)
    wrapper = textwrap.TextWrapper(width=70)
    table.set_style(BeautifulTable.STYLE_NONE)
    table.column_headers = [team, 'pos', 'AB', 'R', 'H', 'RBI', 'BB', 'SO', 'LOB', 'AVG']
    table.column_alignments[team] = BeautifulTable.ALIGN_LEFT
    for batter in data['batter']:
        name=remove_accent(batter['name'])
        if 'note' in batter:
            name=batter['note']+batter['name']
        if len(batter['bo'])==0:
            continue
        batting_order = int(batter['bo'])
        if batting_order%100!=0:
            name = '  '+name
        table.append_row([name, batter['pos'], batter['ab'], batter['r'], batter['h'], batter['rbi'], batter['bb'], batter['so'], batter['bb'], batter['avg']])
    table.append_row(['', '', data['ab'], data['r'], data['h'], data['rbi'], data['bb'], data['so'], data['bb'], data['avg']])
    table_text = str(table).split('\n')
    table_text[0] = '\033[1;32;44m'+table_text[0]+'\033[m'
    table_text[-1] = '\033[1;32;44m'+table_text[-1]+'\033[m'
    print("\n".join(table_text))
    if 'note' in data:
        note = re.compile(r'<.*?>').sub('', data['note'])
        note_line = re.compile(r'\. ').sub('.\n', note)
        print(remove_accent(note_line))

    text_data = re.compile(r'<br/>').sub('\n', data['text_data'][5:])
    text_data = text_data.split('\n')
    out=''
    for text in text_data:
        out = out+'\n'+'\n'.join(wrapper.wrap(text=text))
    text_data = re.compile(r'<b>(.*)</b>').sub(r'\033[1;33m\1\033[m', out)
    print(remove_accent(text_data))
    print('')

def pitcher(data, team):
    table = BeautifulTable(default_alignment=ALIGN_RIGHT, max_width=70)
    table.set_style(BeautifulTable.STYLE_NONE)
    table.column_headers = [team, 'IP', 'H', 'R', 'ER', 'BB', 'SO', 'HR', 'ERA']
    table.column_alignments[team] = BeautifulTable.ALIGN_LEFT
    for pitcher in data['pitcher']:
        inn,outs = divmod(int(pitcher['out']), 3)
        name = remove_accent(pitcher['name'])
        if 'note' in pitcher:
            name = name+' '+ pitcher['note']
        table.append_row([name, "%d.%d"%(inn, outs), pitcher['h'], pitcher['r'], pitcher['er'], pitcher['bb'], pitcher['so'], pitcher['hr'], pitcher['era']])
    inn,outs = divmod(int(data['out']), 3)
    table.append_row(['', "%d.%d"%(inn, outs), data['h'], data['r'], data['er'], data['bb'], data['so'], data['hr'], data['era']])
    table_text = str(table).split('\n')
    table_text[0] = '\033[1;32;44m'+table_text[0]+'\033[m'
    table_text[-1] = '\033[1;32;44m'+table_text[-1]+'\033[m'
    print(remove_accent("\n".join(table_text)))
    print('')

def parse(game):
    global logger
    wrapper = textwrap.TextWrapper(width=70)
    logger.info('parsing game: %s@%s %s %s', game['away_name_abbrev'], game['home_name_abbrev'], game['time_date'], game['time_zone'])

    linescore(game)
    print()
    print(remove_accent('\033[1;33mW: %s %s (%s-%s %s)\033[m'%(game['winning_pitcher']['first'], game['winning_pitcher']['last'], game['winning_pitcher']['wins'], game['winning_pitcher']['losses'], game['winning_pitcher']['era'])))
    print(remove_accent('L: %s %s (%s-%s %s)'%(game['losing_pitcher']['first'], game['losing_pitcher']['last'], game['losing_pitcher']['wins'], game['losing_pitcher']['losses'], game['losing_pitcher']['era'])))
    if len(game['save_pitcher']['id'])>0:
        print(remove_accent('\033[1;36mSV: %s %s (%sS)\033[m'%(game['save_pitcher']['first'], game['save_pitcher']['last'], game['save_pitcher']['saves'])))
    print()
    scoring_summary(game)

    url = 'https://gd2.mlb.com%s/boxscore.json'%(game['game_data_directory'])
    logger.info("fetch boxscore data from %s", url)
    r = urllib.request.urlopen(url).read()
    box = ujson.loads(r.decode('utf-8'))
    hitter(box['data']['boxscore']['batting'][1], box['data']['boxscore']['away_sname'])
    hitter(box['data']['boxscore']['batting'][0], box['data']['boxscore']['home_sname'])
    pitcher(box['data']['boxscore']['pitching'][0], box['data']['boxscore']['away_sname'])
    pitcher(box['data']['boxscore']['pitching'][1], box['data']['boxscore']['home_sname'])

    game_data = box['data']['boxscore']['game_info']
    text_data = re.compile(r'<br/>').sub('\n', game_data)
    text_data = text_data.split('\n')
    out=''
    for text in text_data:
        out = out+'\n'+'\n'.join(wrapper.wrap(text=text))
    text_data = re.compile(r'<b>(.*)</b>').sub(r'\033[1;33m\1\033[m', out)
    print(remove_accent(text_data))
def main():
    global logger
    args = sys.argv
    parser = argparse.ArgumentParser()
    parser.add_argument("year", help="year of game date", type=int)
    parser.add_argument("month", help="month of game date", type=int)
    parser.add_argument("day", help="day of game date", type=int)
    parser.add_argument("team", help="team name of the game", type=str)
    args = parser.parse_args()

    base_url = 'https://gd2.mlb.com/components/game/mlb/year_%d/month_%02d/day_%02d/master_scoreboard.json'%(args.year, args.month, args.day)
    logger.info("fetch all game data from %s", base_url)
    r = urllib.request.urlopen(base_url).read()
    game_list = ujson.loads(r.decode('utf-8'))
    for game in game_list['data']['games']['game']:
        logger.debug("Game: %s@%s", game['away_name_abbrev'], game['home_name_abbrev'])
        if game['away_name_abbrev']==args.team or game['home_name_abbrev']==args.team:
            parse(game)
# Main body
if __name__ == '__main__':
    main()
