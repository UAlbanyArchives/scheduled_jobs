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

print (str(datetime.now()) + " Exporting Records from ArchivesSpace")
client = ASnakeClient()

lastExportTime = time.time()
#timePath = "/app/lastExport.txt"
timePath = "lastExport.txt"
if os.path.isfile(timePath):
    with open(timePath, 'r') as timeFile:
        startTime = int(timeFile.read().replace('\n', ''))
        timeFile.close()
else:
    startTime = 0
humanTime = datetime.fromtimestamp(startTime, UTC).strftime('%Y-%m-%d %H:%M:%S')
print ("\tChecking for collections updated since " + humanTime)

if os.name == "nt":
    output_path = "out_data"
    pdf_path = "out_data"
    ndpaListPath = r"\\Lincoln\Library\SPE_Processing\ndpaList.txt"
else:
    output_path = "/media/Library/SPE_Automated/collections"
    pdf_path = "/media/Library/SPEwww/browse/pdf"
    ndpaListPath = "/media/Library/SPE_Processing/ndpaList.txt"

#Get list of NDPA IDs
ndpaListFile = open(ndpaListPath, "r")
ndpaList = ndpaListFile.read().splitlines() 
ndpaListFile.close()

print ("\tQuerying ArchivesSpace...")
modifiedList = client.get("repositories/2/resources?all_ids=true&modified_since=" + str(startTime)).json()
if len(modifiedList) > 0:
    print ("\tFound " + str(len(modifiedList)) + " new records!")
    print ("\tArchivesSpace URIs: " + str(modifiedList))
else:
    print ("\tFound no new records.")

for colID in modifiedList:
    collection = client.get(f"repositories/2/resources/{colID}").json()
    if collection["publish"] != True: 
        print ("\t\tSkipping " + collection["title"] + " because it is unpublished")
    else:
        print ("\t\tExporting " + collection["title"] + " " + "(" + collection["id_0"] + ")")

        ID = collection["id_0"].lower().strip()
        resourceID = collection["uri"].split("/resources/")[1]
        params = {"include_daos": True}

        #sorting collection
        if ID.startswith("ger"):
            eadDir = os.path.join(output_path, "ger")
        if ID.startswith("ua"):
            eadDir = os.path.join(output_path, "ua")
        if ID.startswith("mss"):
            eadDir = os.path.join(output_path, "mss")
        if ID.startswith("apap"):
            if ID.split(".")[0] in ndpaList:
                eadDir = os.path.join(output_path, "ndpa")
            else:
                eadDir = os.path.join(output_path, "apap")
        if not os.path.isdir(eadDir):
            os.mkdir(eadDir)

        print ("\t\t\tExporting EAD")     
        eadResponse = client.get("repositories/2/resource_descriptions/" + resourceID + ".xml", params=params)
        eadFile = os.path.join(eadDir, ID + ".xml")
        with open(eadFile, 'w', encoding='utf-8') as f:
            f.write(eadResponse.text)
        print ("\t\t\tSuccess!")

        print ("\t\t\tExporting PDF")
        pdfResponse = client.get(f"repositories/2/resource_descriptions/{resourceID}.pdf", params=params)
        pdfFile = os.path.join(pdf_path, ID + ".pdf")
        with open(pdfFile, 'wb') as f:
            f.write(pdfResponse.content)
        print ("\t\t\tSuccess!")


if len(modifiedList) > 0:
    print (f"\tCommitting {len(modifiedList)} new EAD to collections repo...")
    commit_message = f"Modified collections exported from ArchivesSpace."

    try:
        run_git_command(["git", "add", "."], cwd=output_path)
        run_git_command(["git", "commit", "-m", commit_message], cwd=output_path)
        run_git_command(["git", "push", "origin", "main"], cwd=output_path)
        print("Push complete.")
    except RuntimeError as e:
        print(e)
