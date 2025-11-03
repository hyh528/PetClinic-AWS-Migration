# import json
# import os
# import urllib.request
#
# def handler(event, context):
#     """
#     Handles an SNS event and sends a message to a Microsoft Teams channel.
#     """
#     print(f"Event: {json.dumps(event)}")
#
#     teams_webhook_url = os.environ.get("TEAMS_WEBHOOK_URL")
#     if not teams_webhook_url:
#         print("Error: TEAMS_WEBHOOK_URL environment variable is not set.")
#         return {"statusCode": 500, "body": "TEAMS_WEBHOOK_URL not set"}
#
#     try:
#         # Extract message from SNS event
#         sns_message = json.loads(event["Records"][0]["Sns"]["Message"])
#         alarm_name = sns_message.get("AlarmName", "N/A")
#         alarm_description = sns_message.get("AlarmDescription", "N/A")
#         new_state_reason = sns_message.get("NewStateReason", "N/A")
#         region = sns_message.get("Region", "N/A")
#
#         # Create a message card for Teams
#         teams_message = {
#             "@type": "MessageCard",
#             "@context": "http://schema.org/extensions",
#             "themeColor": "FF0000",  # Red for alarm
#             "summary": f"AWS CloudWatch Alarm: {alarm_name}",
#             "sections": [
#                 {
#                     "activityTitle": f"**AWS CloudWatch Alarm: {alarm_name}**",
#                     "activitySubtitle": f"Region: {region}",
#                     "facts": [
#                         {
#                             "name": "Description",
#                             "value": alarm_description
#                         },
#                         {
#                             "name": "Reason",
#                             "value": new_state_reason
#                         }
#                     ],
#                     "markdown": True
#                 }
#             ]
#         }
#
#         # Send the message to Teams
#         req = urllib.request.Request(
#             teams_webhook_url,
#             data=json.dumps(teams_message).encode("utf-8"),
#             headers={"Content-Type": "application/json"}
#         )
#         with urllib.request.urlopen(req) as response:
#             print(f"Message sent to Teams. Status code: {response.getcode()}")
#             return {"statusCode": 200, "body": "Message sent successfully"}
#
#     except Exception as e:
#         print(f"Error processing event: {e}")
#         return {"statusCode": 500, "body": f"Error: {e}"}