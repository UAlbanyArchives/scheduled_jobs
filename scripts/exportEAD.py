import os
import time
import subprocess
from datetime import datetime, UTC
from asnake.client import ASnakeClient

def run_git_command(command, cwd):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Git command failed: {' '.join(command)}\n{result.stderr}")
    return result.stdout.strip()

def export_file(client, endpoint, filepath, binary=False, params=None):
    response = client.get(endpoint, params=params)
    mode = 'wb' if binary else 'w'
    with open(filepath, mode, encoding=None if binary else 'utf-8') as f:
        f.write(response.content if binary else response.text)
    print("\t\t\tSuccess!")

print(f"{datetime.now()} Exporting Records from ArchivesSpace")
client = ASnakeClient()

lastExportTime = time.time()
timePath = "lastExport.txt"
if os.path.isfile(timePath):
    with open(timePath, 'r') as timeFile:
        startTime = int(timeFile.read().replace('\n', ''))
else:
    startTime = 0

humanTime = datetime.fromtimestamp(startTime, UTC).strftime('%Y-%m-%d %H:%M:%S')
print(f"\tChecking for collections updated since {humanTime}")

if os.name == "nt":
    output_path = "out_data"
    pdf_path = "out_data"
    ndpaListPath = r"\\Lincoln\Library\SPE_Processing\ndpaList.txt"
else:
    output_path = "/media/Library/SPE_Automated/collections"
    pdf_path = "/media/Library/SPEwww/browse/pdf"
    ndpaListPath = "/media/Library/SPE_Processing/ndpaList.txt"

# Get list of NDPA IDs
with open(ndpaListPath, "r") as ndpaListFile:
    ndpaList = ndpaListFile.read().splitlines()

print("\tQuerying ArchivesSpace...")
modifiedList = client.get(f"repositories/2/resources?all_ids=true&modified_since={startTime}").json()
if modifiedList:
    print(f"\tFound {len(modifiedList)} new records!")
    print(f"\tArchivesSpace URIs: {modifiedList}")
else:
    print("\tFound no new records.")

for colID in modifiedList:
    collection = client.get(f"repositories/2/resources/{colID}").json()
    if collection["publish"] is not True: 
        print(f"\t\tSkipping {collection['title']} because it is unpublished")
        continue

    print(f"\t\tExporting {collection['title']} ({collection['id_0']})")

    ID = collection["id_0"].lower().strip()
    resourceID = collection["uri"].split("/resources/")[1]
    params = {"include_daos": True}

    # sorting collection
    if ID.startswith("ger"):
        eadDir = os.path.join(output_path, "ger")
    elif ID.startswith("ua"):
        eadDir = os.path.join(output_path, "ua")
    elif ID.startswith("mss"):
        eadDir = os.path.join(output_path, "mss")
    elif ID.startswith("apap"):
        if ID.split(".")[0] in ndpaList:
            eadDir = os.path.join(output_path, "ndpa")
        else:
            eadDir = os.path.join(output_path, "apap")

    if not os.path.isdir(eadDir):
        os.mkdir(eadDir)

    print("\t\t\tExporting EAD")
    eadFile = os.path.join(eadDir, f"{ID}.xml")
    export_file(client, f"repositories/2/resource_descriptions/{resourceID}.xml", eadFile, params=params)

    print("\t\t\tExporting PDF")
    pdfFile = os.path.join(pdf_path, f"{ID}.pdf")
    export_file(client, f"repositories/2/resource_descriptions/{resourceID}.pdf", pdfFile, binary=True, params=params)

if modifiedList:
    print(f"\tCommitting {len(modifiedList)} new EAD to collections repo...")
    commit_message = "Modified collections exported from ArchivesSpace."

    try:
        run_git_command(["git", "add", "."], cwd=output_path)
        run_git_command(["git", "commit", "-m", commit_message], cwd=output_path)
        run_git_command(["git", "push", "origin", "main"], cwd=output_path)
        print("Push complete.")
    except RuntimeError as e:
        print(e)
