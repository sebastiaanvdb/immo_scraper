from src.web_scraper import simple_get
from bs4 import BeautifulSoup

raw_html = simple_get('https://www.defooz.com/te-koop?price-min=&price-max=&reference=&view=list')
# print(len(raw_html))

no_html = simple_get('https://realpython.com/blog/nope-not-gonna-find-it')
# print(no_html is None)

html = BeautifulSoup(raw_html, 'html.parser')
for p in html.select('p'):
    if 'Sint-Amandsberg' in p.text:
        print(p.text)
