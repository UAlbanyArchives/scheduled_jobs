import os
import time
import json
import requests
from datetime import datetime

if os.name == "nt":
    output_path = "new_online_content.json"
else:
    output_path = "/media/Library/SPEwww/static/new_online_content2.json"

ts = time.time()
timestamp = datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
print (f"Running at {timestamp}")

collecting_area_map = {
    'New York State Modern Political Archive': 'apap',
    'National Death Penalty Archive': 'ndpa',
    'German and Jewish Intellectual Émigré Collections': 'ger',
    'Business, Literary, and Local History Manuscripts': 'mss',
    'University Archives': 'ua'
}

solr_core = "arclight-1.4_dao"
#query = "https://solr2020.library.albany.edu:8984/solr/hyrax/select?q=human_readable_type_sim:Dao&sort=system_create_dtsi+desc&rows=1000"
query = f"https://solr2020.library.albany.edu:8984/solr/{solr_core}/select?fq=has_online_content_ssim%3A%22View%20only%20online%20content%22&sort=dado_date_uploaded_ssm%20desc&rows=1000"
print (f"\tquerying {query}")
r = requests.get(query)
print (f"\t--> {r.status_code}")
if r.status_code == 200:
    unique_collection_numbers = set()
    output = []

    for dao in r.json()["response"]["docs"]:
        #print (f"\t\tfound {dao['title_tesim'][0]}")
        mapping = {
            "title": "title_tesim",
            "collection_id": "_root_",
            "collection": "collection_ssim",
            "type": "dado_resource_type_ssim",
            "date": "normalized_date_ssm",
            "thumbnail": "thumbnail_path_ss",
            "id": "id",
            "collecting_area": "repository_ssm",
            "parent_ids": "parent_ssim",
            "parents": "parent_unittitles_ssm"
        }
        obj = {}
        
        if dao["_root_"][0] not in unique_collection_numbers:
            for key in mapping.keys():
                if mapping[key] in dao.keys():
                    if isinstance(dao[mapping[key]], list):
                        if "parent" in key:
                            obj[key] = dao[mapping[key]]
                        else:
                            obj[key] = dao[mapping[key]][0]
                    else:
                        obj[key] = dao[mapping[key]]
            if "dado_date_uploaded_ssm" in dao.keys():
                #obj["added"] = datetime.strptime(dao["dado_date_uploaded_ssm"][0], "%Y-%m-%dT%H:%M:%S%z").strftime("%B %d, %Y")
                obj["added"] = datetime.fromisoformat(dao["dado_date_uploaded_ssm"][0]).strftime("%B %d, %Y")
                if obj["collecting_area"] in collecting_area_map.keys():
                    obj["collecting_area_code"] = collecting_area_map[obj["collecting_area"]];                
                output.append(obj)
                
                unique_collection_numbers.add(obj["collection_id"])
                # stop the loop if we've found three objects from different collections
                if len(unique_collection_numbers) == 3:
                    print (f"\tFound 3 objects from different collections.")
                    break
    print (f"\tWriting results to {output_path}.")
    with open(output_path, "w") as output_file:
        json.dump(output, output_file, indent=4)

    ts = time.time()
    timestamp = datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
    print (f"Finished at {timestamp}")
