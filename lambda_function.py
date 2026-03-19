import boto3
import json
import logging
import os
from datetime import datetime

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
ec2_client = boto3.client('ec2')
sns_client = boto3.client('sns')

# Environment variables (set these in Lambda console)
INSTANCE_ID   = os.environ['INSTANCE_ID']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')

    logger.info(f"Lambda triggered at {timestamp}")
    logger.info(f"Event received: {json.dumps(event)}")

    try:
        # Step 1 - Get current instance state
        instance_state = get_instance_state(INSTANCE_ID)
        logger.info(f"Instance {INSTANCE_ID} current state: {instance_state}")

        # Step 2 - Only restart if running
        if instance_state != 'running':
            message = f"Instance {INSTANCE_ID} is not running. State: {instance_state}. Skipping restart."
            logger.warning(message)
            send_sns_notification(
                subject="EC2 Restart Skipped",
                message=message,
                timestamp=timestamp
            )
            return build_response(200, message)

        # Step 3 - Stop the instance
        logger.info(f"Stopping instance {INSTANCE_ID}...")
        ec2_client.stop_instances(InstanceIds=[INSTANCE_ID])

        # Step 4 - Wait until stopped
        waiter = ec2_client.get_waiter('instance_stopped')
        waiter.wait(InstanceIds=[INSTANCE_ID])
        logger.info(f"Instance {INSTANCE_ID} stopped successfully")

        # Step 5 - Start the instance
        logger.info(f"Starting instance {INSTANCE_ID}...")
        ec2_client.start_instances(InstanceIds=[INSTANCE_ID])

        # Step 6 - Wait until running
        waiter = ec2_client.get_waiter('instance_running')
        waiter.wait(InstanceIds=[INSTANCE_ID])
        logger.info(f"Instance {INSTANCE_ID} started successfully")

        # Step 7 - Send success notification
        message = f"EC2 instance {INSTANCE_ID} restarted successfully at {timestamp}."
        send_sns_notification(
            subject="EC2 Instance Restarted Successfully",
            message=message,
            timestamp=timestamp
        )
        return build_response(200, message)

    except Exception as e:
        error_message = f"Failed to restart instance {INSTANCE_ID}. Error: {str(e)}"
        logger.error(error_message)
        send_sns_notification(
            subject="EC2 Restart FAILED",
            message=error_message,
            timestamp=timestamp
        )
        return build_response(500, error_message)


def get_instance_state(instance_id):
    response = ec2_client.describe_instances(InstanceIds=[instance_id])
    state = response['Reservations'][0]['Instances'][0]['State']['Name']
    return state


def send_sns_notification(subject, message, timestamp):
    full_message = f"""
    Timestamp  : {timestamp}
    Subject    : {subject}
    Message    : {message}
    Instance ID: {INSTANCE_ID}
    """
    sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=full_message
    )
    logger.info(f"SNS notification sent: {subject}")


def build_response(status_code, message):
    return {
        'statusCode': status_code,
        'body': json.dumps({'message': message})
    }
