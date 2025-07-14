import json
import requests
import traceback
import urllib.request
from datetime import datetime

try:
	asBG = "/media/Library/SPEwww/find-it/img/background.jpg"
	descFile = "/media/Library/SPEwww/find-it/bgDesc.json"

	print (f"Started at {datetime.now()}")

	r = requests.get('https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8')
	print (f"\t--> {r.status_code}")

	imageData = r.json()["images"][0]
	url = "https://www.bing.com" + imageData["url"]
	desc = imageData["copyright"]
	title = imageData["title"]
	if "(" in desc:
		desc = desc.split("(")[0].strip()
	moreDetails = imageData["copyrightlink"]

	urllib.request.urlretrieve(url, asBG)

	data = {"description": desc, "link": moreDetails, "title": title}
	print (f"\tWriting to {descFile}...")
	with open(descFile, 'w') as outfile:
	    json.dump(data, outfile)

except Exception as e:
    print(f"Error at {datetime.now()}:\n{traceback.format_exc()}\n")
