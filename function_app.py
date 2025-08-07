import azure.functions as func
import logging
import base64
import html
from email import policy
from email.parser import BytesParser
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="convertEmlToPdf", methods=["POST"])
async def convertEmlToPdf(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Processing request...')

    try:
        req_body = req.get_json()
        file_content_base64 = req_body.get('file')

        # If no file is provided, return an error
        if file_content_base64:

            # Decode the base64 encoded file content
            logging.info("File content received, decoding...")
            file_content = base64.b64decode(file_content_base64)

            # Parse the EML file content
            logging.info("Parsing EML file content...")
            msg = BytesParser(policy=policy.default).parsebytes(file_content)

            # Get the body of the email
            logging.info("Extracting email body...")
            msg_body = msg.get_body(preferencelist=('html', 'plain'))
            
            # Make soup object from the email body 
            soup = BeautifulSoup(msg_body.get_content(), 'html.parser')

            # Create a header with email metadata
            logging.info("Creating header with email metadata...")
            header = '<div>'
            header += f'<b>Date:</b> {html.escape(msg["date"])}<br>'
            header += f'<b>Subject:</b> {html.escape(msg["subject"])}<br>'
            header += f'<b>From:</b> {html.escape(msg["from"])}<br>'
            header += f'<b>To:</b> {html.escape(msg["to"])}<br>'
            # If CC is present, add it to the header
            if msg["cc"]:
                header += f'<b>CC:</b> {html.escape(msg["cc"])}<br>'
            
            headerAttachments = ''

            # Iterate through the email parts to find attachments and inline images
            logging.info("Processing email parts for attachments and inline images...")
            for part in msg.walk():
                # For attachments add filename to headerAttachments
                if part.get_content_disposition() == 'attachment':
                   
                    headerAttachments += f'<li>{html.escape(part.get_filename())}</li>'
                # For inline images, replace the src with base64 data
                if part.get_content_disposition() == 'inline':
                    logging.info(f"Content-Id: {part.get('Content-Id')[1:-1] }")
                
                    # Find the image tag in the soup object
                    imgTag = soup.find(src='cid:'+part.get('Content-Id')[1:-1])

                    # If the image tag is found, replace the src with base64 data   
                    if imgTag:
                        imgTag['src'] = 'data:' + part.get_content_type() + ';base64,' + base64.b64encode(part.get_payload(decode=True)).decode('utf-8')
                        logging.info(f"Image data embedded.")

            if headerAttachments:
                header += '<b>Attachments:</b><ul>'
                header += headerAttachments
                header += '</ul>'

            header += '<hr><br></div>'
            headerFragment = BeautifulSoup(header, 'html.parser')

            # Insert the header at the beginning of the body
            soup.body.insert_before(headerFragment)

            # Insert styling to the HTML
            soup.head.insert_before(BeautifulSoup('<style>@media print { img {max-width: 100% !important; max-height: 100% !important; } }</style>', 'html.parser'))

            # Convert the modified HTML to PDF
            logging.info("Converting HTML to PDF...")
            async with async_playwright() as p:
                # Launch a headless browser and create a new page
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()
                # Set the content of the page to the extracted and modified HTML
                await page.set_content(str(soup.prettify(formatter="html")))
                # Generate the PDF from the page content in A4 format
                pdf = await page.pdf(format='A4')
                # Close the browser
                await browser.close()
                logging.info("PDF conversion completed.")

            return func.HttpResponse(
                pdf,
                mimetype="application/pdf",
                status_code=200
            )
        
        else:
            return func.HttpResponse("No file found in request body.", status_code=400)
        
    except Exception as e:

        logging.error(f"Error processing request: {e}")

        return func.HttpResponse("Something went wrong.", status_code=400)