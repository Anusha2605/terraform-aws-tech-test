import boto3
import datetime
import time
from datetime import datetime as dt
from pprint import pprint
def lambda_handler(event, context):
    # Connect to EC2 and DynamoDB client
    client = boto3.client("ec2")
    dynamodb = boto3.resource('dynamodb')
    #Get EC2 instance statuses
    status = client.describe_instance_status(IncludeAllInstances = True)
    #pprint(status)
    #Get ttl time
    days = dt.today() + datetime.timedelta(days=1)
    expiryDateTime = int(time.mktime(days.timetuple()))
    
    #Connect to right table in Dynamodb
    table = dynamodb.Table('ec2_instance_status')
    #Report data to Dynamodb table
    try:
        for i in status["InstanceStatuses"]:
            pprint(i)
            #get current datetime
            currenttime = round(time.time() * 1000)
            table.put_item(
                Item={
                    "currentdatetime": str(currenttime),
                    "InstanceId": i['InstanceId'],
                    "InstanceState": i["InstanceState"]["Name"],
                    "expirydatetime": str(expiryDateTime)
                }
            )
        return True
    
    except Exception as e: 
        print('Exception: ', e) 
        return False
