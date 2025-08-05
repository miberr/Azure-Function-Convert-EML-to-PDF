import azure.functions as func
import logging
import base64
import html
from email import policy
from email.parser import BytesParser
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="convertEmlToPdf", methods=["POST"])
async def convertMsgToPdf(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Processing request...')

    try:
        req_body = req.get_json()
        file_content_base64 = req_body.get('file')

        # If no file is provided, return an error
        if file_content_base64:

            file_content = base64.b64decode(file_content_base64)

            msg = BytesParser(policy=policy.default).parsebytes(file_content)

            
            # Try to extract information from the email
            logging.info("Extracting email information...")
            logging.info(f"Subject: {msg['subject']}")
            logging.info(f"From: {msg['from']}")    
            logging.info(f"To: {msg['to']}")
            logging.info(f"CC: {msg['cc']}")
            logging.info(f"Date: {msg['date']}")

            msg_body = msg.get_body(preferencelist=('html', 'plain'))
            
            soup = BeautifulSoup(msg_body.get_content(), 'html.parser')

            # Add header to the HTML
            header = '<div>'
            header += f'<b>Date:</b> {html.escape(msg["date"])}<br>'
            header += f'<b>Subject:</b> {html.escape(msg["subject"])}<br>'
            header += f'<b>From:</b> {html.escape(msg["from"])}<br>'
            header += f'<b>To:</b> {html.escape(msg["to"])}<br>'
            if msg["cc"]:
                header += f'<b>CC:</b> {html.escape(msg["cc"])}<br>'
            
            headerAttachments = ''

            for part in msg.walk():
                # For attachments add filename and content type to headerAttachments
                if part.get_content_disposition() == 'attachment':
                   
                    headerAttachments += f'<li>{html.escape(part.get_filename())} ({part.get_content_type()})</li>'
                    logging.info(f"Found an attachment: {part.get_filename()}")

                if part.get_content_disposition() == 'inline':
                    logging.info(f"Found an inline part: {part.get_filename()}")

                    logging.info(f"Content-Id: {part.get('Content-Id')[1:-1] }")
                
                    imgTag = soup.find(src='cid:'+part.get('Content-Id')[1:-1])

                    logging.info(f"Image tag found: {imgTag}")

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

            # Convert the modified HTML to PDF
            logging.info("Converting HTML to PDF...")
      
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()
                await page.set_content(str(soup.prettify(formatter="html")))
                pdf = await page.pdf(format='A4', print_background=True)
                await browser.close()
                logging.info("PDF conversion completed.")

            #logging.info(f"Modified HTML: {soup.prettify()}")

            return func.HttpResponse(
                pdf,
                mimetype="application/pdf",
                status_code=200
            )
        
            # return func.HttpResponse("Successfully decoded file content.", status_code=200)
        else:
            return func.HttpResponse("No file found in request body.", status_code=400)
        
    except Exception as e:

        logging.error(f"Error processing request: {e}")

        return func.HttpResponse("Something went wrong.", status_code=400)