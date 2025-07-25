import os
import yaml
import time
import json
import requests
from datetime import datetime
from dateutil.parser import parse

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
query = f"https://solr2020.library.albany.edu:8984/solr/{solr_core}/select?fq=has_online_content_ssim%3A%22View%20only%20online%20content%22&sort=dado_date_uploaded_ssi%20desc&rows=10"
#print (f"\tquerying {query}")
r = requests.get(query)

if r.status_code == 200:
    docs = r.json()["response"]["docs"]
    collection_to_obj = {}

    for dao in docs:
        collection_id = dao.get("_root_")
        if isinstance(collection_id, list):
            collection_id = collection_id[0]

        if not collection_id:
            continue

        current_added = dao.get("dado_date_uploaded_ssi")
        if not current_added:
            continue

        try:
            current_dt = parse(current_added)
        except Exception as e:
            print(f"Skipping invalid date: {current_added}")
            continue

        existing = collection_to_obj.get(collection_id)
        if existing is None or current_dt > existing["_added_dt"]:
            # Map fields
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

            obj["added"] = current_dt.strftime("%B %d, %Y")
            obj["_added_raw"] = current_added
            obj["_added_dt"] = current_dt

            if obj.get("collecting_area") in collecting_area_map:
                obj["collecting_area_code"] = collecting_area_map[obj["collecting_area"]]


            collection_to_obj[collection_id] = obj

    # Get most recent 3 across all unique collections
    latest_three = sorted(
        collection_to_obj.values(),
        key=lambda x: x["_added_dt"],
        reverse=True
    )[:3]

    # Remove internal sort field before output
    for item in latest_three:
        item.pop("_added_raw", None)
        item.pop("_added_dt", None)

    with open(output_path, "w") as output_file:
        json.dump(latest_three, output_file, indent=4)

    print(f"\tFinished at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
else:
    print(f"Failed to fetch from Solr: {r.status_code}")