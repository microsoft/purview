# Subject Rights Requests Playbook

This playbook describes how to fulfill **subject rights requests** using **Microsoft Purview eDiscovery** and **Microsoft Graph API**, covering **Access**, **Export**, and **Delete** scenarios.

---

## Roles

### Privacy Admin

- Responds to subject rights request access and export requests using eDiscovery
- Performs searches and prepares identifiers for subject rights request delete operations

---

## Subject Rights Request Case Creation

### Step 1: Create Case

![](Images/srr-case-creation-step-1-create-case-1.png)
- Go to **Microsoft Purview → eDiscovery**
- Requires **eDiscovery Manager** role
- Select **Create case**, then provide a case name and description

### Step 2: Create Search

![](Images/srr-case-creation-step-2-create-search-1.png)
![](Images/srr-case-creation-step-2-create-search-2.png)
You will be able to view/edit case. The information on case would display beneath including case setting, Process manger, number of Searches are created, review sets etc.
- Open the case and go to **Searches**
- Select **Create a search**
- Provide a descriptive name and description

### Step 3: Add Data Sources

![](Images/srr-case-creation-step-3-add-data-sources-1.png)
- Open the **Query** tab
- Add tenant-wide sources or specify user mailboxes / URLs
- Save changes

### Step 4: Add Query Conditions

![](Images/srr-case-creation-step-4-add-query-condition-1.png)
- Use the condition builder
- Enter a KQL query using the following template:
  ```
  (("<full name>" OR "<email>") OR (participants:"<email>"))(c:c)(date>=<one year before SRR submit date>)(-participants=<email>)
  ```
  **Example:**
  ```
  (("Charles Jackson" OR "charles@M365P893818.onmicrosoft.com") OR (participants:"charles@M365P893818.onmicrosoft.com"))(c:c)(date>=2025-02-23)(-participants=charles@M365P893818.onmicrosoft.com)
  ```
  > **Note:** If submitting a new request in eDiscovery, set the date to one year before today. If replicating an existing SRR request, refer to [Find Query Used by Existing SRR Case in Priva Portal](#find-query-used-by-existing-srr-case-in-priva-portal) to retrieve the exact query.
- Run the query

### Step 5: Run Search

![](Images/srr-case-creation-step-5-run-search-1.png)
- Use default result settings or customize as needed

### Step 6: Review Search Statistics

![](Images/srr-case-creation-step-6-review-search-statistics-1.png)
- Review total matches, locations, and data sources
- Refine the query or sources if required

### Step 7: Create Review Set

![](Images/srr-case-creation-step-7-create-review-set-1.png)
- Select **Add to review set**
- Create a new review set or reuse an existing one

### Step 8: Review Review Set

![](Images/srr-case-creation-step-8-review-review-set-1.png)
- Browse returned content
- Validate search accuracy

### Step 9: Tag Files

![](Images/srr-case-creation-step-9-tag-file-1.png)
- Select files within the review set
- Apply existing tags or create new ones
![](Images/srr-case-creation-step-9-create-tag-1.png)
- Create new Tags

### Step 10: Filter Data

![](Images/srr-case-creation-step-10-filter-data-1.png)
- Filter results by tags
- Review file content

### Step 11: Redact Sensitive Data

![](Images/srr-case-creation-step-11-redact-sensitive-data-1.png)
![](Images/srr-case-creation-step-11-redact-sensitive-data-2.png)
- Open a file and go to the **Annotate** tab
- Use **Area redaction** to remove sensitive information

### Step 12: Create Export

![](Images/srr-case-creation-step-12-create-export-1.png)
![](Images/srr-case-creation-step-12-create-export-2.png)
- Select files → **Actions → Export**
- Enable:
  - Export with item report
  - Export redactions

### Step 13: Export

![](Images/srr-case-creation-step-13-export-1.png)
- Wait until export status shows **Completed**

### Step 14: Download Export Package

![](Images/srr-case-creation-step-14-download-export-package-1.png)
![](Images/srr-case-creation-step-14-download-export-package-2.png)
![](Images/srr-case-creation-step-14-download-export-package-3.png)
![](Images/srr-case-creation-step-14-download-export-package-4.png)
![](Images/srr-case-creation-step-14-download-export-package-5.png)
- After complete, select Export file name 
- Select Export Packages and select **Download**
- Download export packages:
  - **SharePoint and OneDrive**: `Items-<CaseName>.zip`
  - **Email**: `PSTs-<CaseName>.zip`
  - **Metadata**: `Reports-<CaseName>.zip`

### Step 15: Retrieve Identifiers (For Delete)

![](Images/srr-case-creation-step-15-get-identifiers-1.png)
- Use metadata CSV files from `Reports-<CaseName>.zip`

---

## Subject Rights Request Case Delete – Email Deletion (eDiscovery and Graph API)

### Prerequisites
- Roles:
  - **eDiscovery Manager**
  - **Search and Purge**

### Step 1: Create Search

![](Images/email-deletion-step-1-create-search-1.png)
- Create a search in eDiscovery

### Step 2: Add KeyQL Condition

![](Images/email-deletion-step-2-add-query-condition-1.png)
- Add **KeyQL** condition using `internetMessageId`

### Step 3: Add Mailbox Sources

![](Images/email-deletion-step-3-add-data-source-1.png)
- Add tenant-wide mailbox sources

### Step 4: Run Query

![](Images/email-deletion-step-4-run-query-1.png)
- Run the query

### Step 5: Review Search Statistics

![](Images/email-deletion-step-5-review-search-statistics-1.png)
- Review search statistics

### Step 6: Review Sample Content

![](Images/email-deletion-step-6-review-content-1.png)
- Review sample content

### Step 7: Sign In to Graph Explorer

![](Images/email-deletion-step-7-login-graph-explorer-1.png)
- Sign in to **Graph Explorer** with Purview credentials

### Step 8: Grant Required Permissions

![](Images/email-deletion-step-8-grant-permission-consent-1.png)
- Grant required permissions

### Step 9: Retrieve Case ID

![](Images/email-deletion-step-9-get-case-1.png)
- Retrieve **Case ID** via Graph API

### Step 10: Retrieve Search ID

![](Images/email-deletion-step-10-get-search-1.png)
- Retrieve **Search ID** via Graph API

### Step 11: Execute Purge

![](Images/email-deletion-step-11-run-purge-1.png)
- Execute purge with:
  - `PurgeArea = mailboxes`
  - `PurgeType = permanentlyDelete`

---

## Subject Rights Request Case Delete – Teams Message Deletion (eDiscovery and Graph API)

### Step 1: Create Search

![](Images/teams-deletion-step-1-create-search-1.png)
- Create a search in eDiscovery

### Step 2: Add KeyQL Condition

![](Images/teams-deletion-step-2-add-query-condition-1.png)
- Add Teams **KeyQL** condition

### Step 3: Add Mailbox Data Source

![](Images/teams-deletion-step-3-add-data-source-1.png)
- Add mailbox data source

### Step 4: Run Query

![](Images/teams-deletion-step-4-run-query-1.png)
- Run the query

### Step 5: Review Search Statistics

![](Images/teams-deletion-step-5-review-search-statistics-1.png)
- Review search statistics

### Step 6: Review Content

![](Images/teams-deletion-step-6-review-content-1.png)
- Review content via review set

### Step 7: Sign In to Graph Explorer

![](Images/teams-deletion-step-7-login-graph-explorer-1.png)
- Sign in to **Graph Explorer**

### Step 8: Grant Required Permissions

![](Images/teams-deletion-step-8-grant-permission-consent-1.png)
- Grant required permissions

### Step 9: Retrieve Case ID

![](Images/teams-deletion-step-9-search-case-1.png)
- Retrieve **Case ID** and **Search ID**

### Step 10: Retrieve Search ID

![](Images/teams-deletion-step-10-purge-1.png)
- Retrieve **Search ID**

### Step 11: Execute Purge

![](Images/teams-deletion-step-11-purge-1.png)
- Execute purge with:
  - `PurgeArea = teamsMessage`
  - `PurgeType = permanentlyDelete`

---

## Subject Rights Request Case Delete – OneDrive and SharePoint Using Script

### Step 1: Export Files

![](Images/odsp-deletion-step-1.png)
- Download export results from eDiscovery

### Step 2: Extract Package

![](Images/odsp-deletion-step-2.png)
- Unzip `Reports-<CaseName>-<timestamp>.zip`

### Step 3: Review CSV

![](Images/odsp-deletion-step-3.png)
- Open `Items_<timestamp>.csv`

![](Images/odsp-deletion-step-4.png)
- Remove files that must be retained
- The script deletes all listed ODSP files
- Email and Teams items are skipped automatically

### Step 4: Run Deletion Script

![](Images/odsp-deletion-step-5.png)
- Download the [**OneDrive & SharePoint File Deletion Tool**](OneDrive%20%26%20SharePoint%20File%20Deletion%20Tool/)
- Follow instructions in `ReadMe.md` in deletion tool package

---

## Find Query Used by Existing SRR Case in Priva Portal

This section describes how to retrieve the search query from an existing Subject Rights Request case in the Priva portal, so it can be reused in eDiscovery searches.

### Step 1: Open Browser Inspector

![](Images/priva-query-step-1-open-inspector-1.png)
- Go to the [Priva SRR portal](https://purview.microsoft.com/priva/dsr)
- Right-click anywhere on the page and select **Inspect**

### Step 2: Set Up Network Filter

![](Images/priva-query-step-2-filter-network-tab-1.png)
- In the Inspector, switch to the **Network** tab
- Enter **privacycases** in the network filter field
- Refresh the page

### Step 3: Switch to Priva SRR View

![](Images/priva-query-step-3-toggle-srr-1.png)
- Switch the toggle back to use **Subject Rights Request in Microsoft Priva**
- Once the page is loaded, a new API record will appear under the Network list

### Step 4: Find the Filter Query

![](Images/priva-query-step-4-find-filter-query-1.png)
- Click the API record, then select the **Response** tab
- Press **Ctrl+F** to search for your case name
- Once you find the payload section for your case, scroll down to find the `filterQuery` field
- Copy the query

### Step 5: Clean Up and Use the Query

- Remove the extra `\` characters from the copied query before using it in eDiscovery search

**Example:**

Query copied from payload:
```
(("Charles Jackson" OR "Charles@M365P893818.onmicrosoft.com") OR (participants:"Charles@M365P893818.onmicrosoft.com"))(c:c)(-participants=Charles@M365P893818.onmicrosoft.com)
```

Query after removing `\`:
```
(("Charles Jackson" OR "Charles@M365P893818.onmicrosoft.com") OR (participants:"Charles@M365P893818.onmicrosoft.com"))(c:c)(-participants=Charles@M365P893818.onmicrosoft.com)
```

- Use the cleaned query in your eDiscovery search

---
