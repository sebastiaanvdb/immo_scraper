from src.web_scraper import simple_get
from bs4 import BeautifulSoup

if __name__ == '__main__':
    raw_html_defooz = simple_get('https://www.defooz.com/te-koop?price-min=&price-max=&reference=&view=list')
    # print(len(raw_html_defooz))

    html = BeautifulSoup(raw_html_defooz, 'html.parser')
    for p in html.select('div'):
        if 'Sint-Amandsberg' in p.text:
            print(p.text)

