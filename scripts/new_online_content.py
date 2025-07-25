import os
import yaml
import time
import json
import requests
from datetime import datetime

if os.name == "nt":
    output_path = "new_online_content.json"
else:
    output_path = "/media/Library/SPEwww/static/new_online_content.json"

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

config_path = '/root/.description_harvester/config.yml'
with open(config_path, 'r') as f:
    config = yaml.safe_load(f)
solr_core = config.get('solr_core')

#query = "https://solr2020.library.albany.edu:8984/solr/hyrax/select?q=human_readable_type_sim:Dao&sort=system_create_dtsi+desc&rows=1000"
query = f"https://solr2020.library.albany.edu:8984/solr/{solr_core}/select?fq=has_online_content_ssim%3A%22View%20only%20online%20content%22&sort=dado_date_uploaded_ssi%20desc&rows=1000"
print (f"\tquerying {query}")
r = requests.get(query)
print (f"\t--> {r.status_code}")
if r.status_code == 200:
    collection_to_obj = {}

    for dao in r.json()["response"]["docs"]:
        collection_id = dao.get("_root_", [None])[0]
        if not collection_id:
            continue

        if collection_id not in collection_to_obj:
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
            for key, solr_key in mapping.items():
                if solr_key in dao:
                    value = dao[solr_key]
                    if isinstance(value, list):
                        if "parent" in key:
                            obj[key] = value
                        else:
                            obj[key] = value[0]
                    else:
                        obj[key] = value
            
            if "dado_date_uploaded_ssm" in dao:
                obj["added"] = datetime.fromisoformat(dao["dado_date_uploaded_ssm"][0]).strftime("%B %d, %Y")
                obj["_added_raw"] = dao["dado_date_uploaded_ssm"][0]  # for sorting later

            if obj.get("collecting_area") in collecting_area_map:
                obj["collecting_area_code"] = collecting_area_map[obj["collecting_area"]]

            collection_to_obj[collection_id] = obj

    # Get most recent 3 across all unique collections
    latest_three = sorted(
        collection_to_obj.values(),
        key=lambda x: x.get("_added_raw", ""),
        reverse=True
    )[:3]

    # Remove internal sort field before output
    for item in latest_three:
        item.pop("_added_raw", None)

    print(f"\tWriting results to {output_path}.")
    with open(output_path, "w") as output_file:
        json.dump(latest_three, output_file, indent=4)
    ts = time.time()
    timestamp = datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
    print (f"Finished at {timestamp}")
