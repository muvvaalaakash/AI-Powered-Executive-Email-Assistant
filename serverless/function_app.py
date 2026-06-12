import azure.functions as func
import logging
import json
import urllib.request
import os

app = func.FunctionApp()

@app.function_name(name="MeetingReminderTrigger")
@app.service_bus_queue_trigger(
    arg_name="msg",
    queue_name="meeting-reminders",
    connection="ServiceBusConnection"
)
def main(msg: func.ServiceBusMessage):
    logger = logging.getLogger("MeetingReminderTrigger")
    
    try:
        body = msg.get_body().decode('utf-8')
        logger.info(f"Received Service Bus reminder event: {body}")
        
        payload = json.loads(body)
        meeting_id = payload.get("meeting_id")
        
        if not meeting_id:
            logger.error("Message body does not contain meeting_id.")
            return
            
        # Call back to the API Gateway to trigger the reminder popup
        gateway_url = os.getenv("API_GATEWAY_URL", "http://localhost:8000")
        trigger_url = f"{gateway_url}/meetings/reminders/{meeting_id}/trigger"
        
        logger.info(f"Triggering reminder webhook on Gateway: {trigger_url}")
        
        req = urllib.request.Request(
            trigger_url,
            method="POST",
            headers={"Content-Type": "application/json"}
        )
        
        with urllib.request.urlopen(req, timeout=15) as response:
            res_body = response.read().decode('utf-8')
            logger.info(f"Gateway trigger response: {res_body}")
            
    except Exception as e:
        logger.error(f"Error handling Service Bus message: {str(e)}")
        raise e
