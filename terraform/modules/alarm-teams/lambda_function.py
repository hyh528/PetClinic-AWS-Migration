import json
import os
import urllib.request

def lambda_handler(event, context):
    teams_webhook_url = os.environ['TEAMS_WEBHOOK_URL']
    
    print("Received event: " + json.dumps(event, indent=2))
    
    message = "CloudWatch Alarm Notification:\n\n"
    
    if 'Records' in event:
        for record in event['Records']:
            if 'Sns' in record:
                sns_message = json.loads(record['Sns']['Message'])
                
                alarm_name = sns_message['AlarmName']
                new_state = sns_message['NewStateValue']
                old_state = sns_message['OldStateValue']
                reason = sns_message['NewStateReason']
                metric_name = sns_message['Trigger']['MetricName']
                threshold = sns_message['Trigger']['Threshold']
                
                message += f"Alarm Name: {alarm_name}\n"
                message += f"New State: {new_state}\n"
                message += f"Old State: {old_state}\n"
                message += f"Reason: {reason}\n"
                message += f"Metric: {metric_name}\n"
                message += f"Threshold: {threshold}%\n"
                message += f"Link: {sns_message['AlarmArn'].replace('arn:aws:cloudwatch:', 'https://console.aws.amazon.com/cloudwatch/home?#alarms:alarm/')}\n"
    else:
        message += "Direct invocation or unexpected event format."

    teams_message = {
        "text": message
    }

    try:
        json_message = json.dumps(teams_message).encode('utf-8')
        req = urllib.request.Request(teams_webhook_url, data=json_message, headers={'Content-Type': 'application/json'})
        response = urllib.request.urlopen(req)
        response.read()
        print(f"Message sent to Teams: {response.status}")
    except Exception as e:
        print(f"Error sending message to Teams: {e}")
        raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notification sent to Teams!')
    }
