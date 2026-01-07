import os
import time
import subprocess
from datetime import datetime, UTC
from asnake.client import ASnakeClient
from lxml import etree

def run_git_command(command, cwd):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Git command failed: {' '.join(command)}\n{result.stderr}")
    return result.stdout.strip()

print(f"{datetime.now()} Exporting Records from ArchivesSpace")
client = ASnakeClient()

lastExportTime = time.time()
timePath = "/opt/lastExport.txt"
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
    pdf_path = "/media/Library/SPEwww/static/pdf"
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
    
    # Export and format EAD XML
    response = client.get(f"repositories/2/resource_descriptions/{resourceID}.xml", params=params)
    try:
        parser = etree.XMLParser(remove_blank_text=True)
        tree = etree.fromstring(response.content, parser)
        with open(eadFile, 'wb') as f:
            f.write(etree.tostring(tree, pretty_print=True, xml_declaration=True, encoding='utf-8'))
        print("\t\t\tSuccess!")
    except Exception as e:
        # Fallback to raw XML if formatting fails
        with open(eadFile, 'w', encoding='utf-8') as f:
            f.write(response.text)
        print(f"\t\t\tSuccess! (Warning: Could not format XML: {e})")

    # Get PDF output file path
    pdfFile = os.path.join(pdf_path, f"{ID}.pdf")
    
    # Create PDF generation job
    job_params = {
        "job": {
            "source": f"/repositories/2/resources/{resourceID}",
            "jsonmodel_type": "print_to_pdf_job",
            "job_type": "print_to_pdf_job",
            "include_unpublished": False,
            "repo_id": 2
        },
        "job_params": "null",
        "jsonmodel_type": "job"
    }
    
    response = client.post("repositories/2/jobs", json=job_params)
    if response.status_code != 200:
        print(f"\t\t\tFailed to create PDF job: {response.json()}")
        continue
    
    response_data = response.json()
    job_id = response_data["id"]
    print(f"\t\t\tPDF job created (ID: {job_id})")
    
    # Poll job status every 30 seconds
    max_attempts = 40  # 20 minutes maximum
    attempt = 0
    while attempt < max_attempts:
        time.sleep(30)
        attempt += 1
        
        job = client.get(f"repositories/2/jobs/{job_id}")
        if job.status_code != 200:
            print(f"\t\t\tFailed to check job status: {job.status_code}")
            break
        
        job_status = job.json()["status"]
        print(f"\t\t\tJob status: {job_status}")
        
        if job_status == "completed":
            # Get output files
            output_files = client.get(f"repositories/2/jobs/{job_id}/output_files")
            if output_files.status_code == 200:
                file_id = output_files.json()[0]
                
                # Download PDF
                file_response = client.get(f"repositories/2/jobs/{job_id}/output_files/{file_id}")
                if file_response.status_code == 200:
                    with open(pdfFile, 'wb', encoding=None) as f:
                        f.write(file_response.content)
                    print("\t\t\tSuccess!")
                else:
                    print(f"\t\t\tFailed to download PDF: {file_response.status_code}")
            else:
                print(f"\t\t\tFailed to get output files: {output_files.status_code}")
            break
        elif job_status == "failed":
            print(f"\t\t\tPDF job failed")
            job_log = client.get(f"repositories/2/jobs/{job_id}/log")
            if job_log.status_code != 200:
                print(f"\t\t\tFailed to retrieve job log: {job_log.status_code}")
            elif job_log.text.count("\n") >= 2:
                # try to just print the second line of the log for error details
                error_line = job_log.text.split('\n')[1]
                print(f"\t\t\t{error_line}")
            else:
                # fall back to printing the whole log indented 3 tabs
                indented_text = job_log.text.replace("\n", "\n\t\t\t")
                print(f"\t\t\t{indented_text}")
            break

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

#print(f"\tWriting export time to {timePath}")
with open(timePath, 'w') as timeFile:
    timeFile.write(str(int(lastExportTime)))
print(f"{datetime.now()} Export complete!")
