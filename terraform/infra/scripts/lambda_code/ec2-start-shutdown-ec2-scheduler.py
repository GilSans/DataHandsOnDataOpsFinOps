import json
import boto3
import os

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    instance_id = event.get('instance_id', os.environ.get('INSTANCE_ID'))
    action = event.get('action', 'status')

    if not instance_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'instance_id is required'})
        }

    try:
        if action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            message = f'Started instance {instance_id}'
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            message = f'Stopped instance {instance_id}'
        elif action == 'status':
            response = ec2.describe_instances(InstanceIds=[instance_id])
            state = response['Reservations'][0]['Instances'][0]['State']['Name']
            message = f'Instance {instance_id} is {state}'
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid action. Use: start, stop, or status'})
            }

        return {
            'statusCode': 200,
            'body': json.dumps({'message': message})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
