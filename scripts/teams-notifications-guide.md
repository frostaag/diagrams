# Teams Notifications f### Success Notification (Green)
- ✅ Visual confirmation that the workflow completed successfully
- Number of files processed with a sample of processed files
- Who triggered the workflow (with profile picture)
- Link to view the specific job logs
- Link to view the complete workflow runw.io Diagrams Workflow

## Overview

The Draw.io diagrams conversion workflow includes automatic Microsoft Teams notifications that alert you when:

1. **Success Notification**: The conversion completes successfully and files are updated
2. **Failure Notification**: The workflow encounters an error during execution

> **Note:** Microsoft Teams webhooks are simple to use - they only require the webhook URL itself. No username, password, or additional authentication is needed as all the authorization is embedded in the URL.

## Sender Identification

By default, webhook messages appear with a generic sender name (often showing as "Unknown user"). Our workflow addresses this by:

1. Including the GitHub user's profile picture using `activityImage: "https://github.com/${{ github.actor }}.png?size=40"`
2. Clearly indicating who triggered the workflow in the message facts
3. Using proper branding and styling to identify the message source

## How It Works

The workflow uses your configured `TEAMS_WEBHOOK` secret to send adaptive cards to your Microsoft Teams channel. These notifications provide:

### Success Notification (Green)
- ✅ Visual confirmation that the workflow completed successfully
- Number of files processed
- Who triggered the workflow
- Confirmation of SharePoint upload
- Link to view the workflow run details

### Failure Notification (Red)
- ⚠️ Immediate alert when something goes wrong
- Which repository and branch had the issue
- Who triggered the workflow
- The commit message that caused the error
- Link to view the workflow run for troubleshooting

## Sample Notifications

### Success:
```
[Profile Picture] ✅ Draw.io Conversion Completed Successfully
---------------------------------------------
Repository: lucasdreger/diagrams
Files Processed: 3 (diagram1, diagram2, diagram3)
Triggered by: lucasdreger
Commit: Update SAP Cloud diagram

[View Job Logs] [View Workflow Run]
```

### Failure:
```
[Profile Picture] ⚠️ Draw.io Conversion Workflow Failed
------------------------------------
Repository: lucasdreger/diagrams
Branch: main
Triggered by: lucasdreger
Commit: Update diagram file
Job: convert (12345678)

⚠️ The diagram conversion workflow has failed. Check the logs for more details.

[View Job Logs] [View Workflow Run]
```

The notifications include the GitHub profile picture of the person who triggered the workflow, making it clear that this message is related to their action.

## Troubleshooting

If notifications aren't being sent:

1. **Check the TEAMS_WEBHOOK secret**: Make sure it's properly configured in your GitHub repository secrets.
2. **Review the workflow run**: Look at the specific step that failed to send the notification.
3. **Webhook expiration**: Teams webhooks can expire. If notifications stop working, you may need to generate a new webhook URL.

## Customizing Notifications

You can customize the notifications by editing the workflow file at `.github/workflows/drawio-convert.yml`. Look for the sections with `Send Teams notification` steps to modify:

- The color of the notification card (`themeColor`)
- The facts displayed in the card
- The title or subtitle text
- Additional actions or buttons
