# Azure Function (Containerized) Convert EML to PDF

This repository contains source files for a containerized Azure Function for converting EML files into PDF 📧. There is also a 💪 Bicep file for easy deployment. Built container available in Docker Hub LINK LINK.

## Features

-   🤓 Function source code for creating your own containers
-   💪 Bicep file for deploying the resources right away
-   🤖 Ready made Azure Logic App to convert incoming emails
-   📦 Built container in Docker Hub LINK LINK

## Installation

> [!NOTE]
>
> #### Prerequisites
>
> -   Azure subscription
> -   Resource group in Azure
> -   [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/what-is-azure-cli?view=azure-cli-latest) installed on your machine
> -   Basic understanding of containerized applications

1. Download the [💪 Bicep file](https://raw.githubusercontent.com/miberr/Azure-Function-Convert-EML-to-PDF/main/infrastructure.bicep) to your machine
1. Open terminal
1. Login to Azure CLI with command `az login`. A popup opens, login with your credentials.
1. If you have multiple subscriptions, select the one you want to deploy to by typing its number and pressing **enter**
1. Run command `az deployment group create --template-file .\infrastructure.bicep --resource-group rg-emailtopdftest-dev --parameters environment=dev appName=emailtopdf` with the following parameters:

    - _.\infrastructure.bicep_ is the path to the downloaded template file
    - _rg-emailtopdftest-dev_ the resource group name
    - _dev_ is the environment, either **dev** or **prod** accepted
    - _emailtopdf_ is the app name, this needs to be unique

    In case there is a conflict with a name for example, the CLI will tell you about it. If you see no red, that means the deployment was successful 🥳.

1. Navigate to your resource group in Azure Portal. It should now look like this:

    <img width="1642" height="927" alt="Screenshot of deployed resources in Azure" src="https://github.com/user-attachments/assets/a78cbc8c-6768-461d-8801-4aedb95c8036" />

1. To initialize the secrets in Key Vault we have to send a POST request to the new endpoint.

    - Find the url by navigating to the **Container App**
    - Copy the value

       <img width="1828" height="618" alt="Finding the url for the container app" src="https://github.com/user-attachments/assets/50273e01-92d7-4def-bff4-723d4798074c" />

    - Add the uri at the end `/api/convertEmlToPdf`
    - Send a request with your chosen tool. Make sure you include the **x-functions-key** header. The value can be what ever, for example `test`. You should get **401 Unauthorized** response back.

        ```http
        POST https://xxxx.westeurope.azurecontainerapps.io/api/convertEmlToPdf
        x-functions-key: test

        {
            "file": "UmVjZWl2ZWQ6IGZyb20gVkkwUDE5MU1..."
        }
        ```

1. The last configuration to do is to open the API connections for Outlook and OneDrive to authorize them. Click on the **first one**.

    <img width="936" height="121" alt="Connections needing authorization" src="https://github.com/user-attachments/assets/96529153-caa4-4ddb-a9ad-74a1b7764eda" />

1. Click on the **error**, then **Authorize**, login with your account and finally select **Save**

    <img width="1148" height="443" alt="Authorize connection" src="https://github.com/user-attachments/assets/53a08af5-139b-4a38-96a8-e4a90ffce5bc" />


1. Repeat for the another connection.
   
1. Now send an email to the inbox you connected to and wait for the file to appear in OneDrive 😎

> [!WARNING]
> You should use what ever account you want to connect to an email to and what users OneDrive. It's best practice to use service accounts for these kind of scenarios.

## Usage

As you now have everything installed, you can just sit back and relax 🏖️. If you require modifications to the Logic App for example, you cannot use the 💪 Bicep file anymore cause it would overwrite the workflow.

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## Acknowledgements

This project was created as part of a blog post on converting emails into PDFs. You can read the full post here.
